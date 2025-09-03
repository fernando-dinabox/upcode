<?php

header('Content-Type: application/json; charset=utf-8');

// =============================
// Configurações
// =============================
$diretorioBase = '/opt/bitnami/apps/wordpress/htdocs/';
$scriptDir = dirname(__FILE__) . DIRECTORY_SEPARATOR;
$permissionsFile = $scriptDir . 'user_permissions.json';
$logFile = $scriptDir . 'upcode_logs.log';

// =============================
// Funções de Debug e Log
// =============================
function debugLog($message, $data = null) {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] $message";
    if ($data !== null) {
        $logEntry .= " | Data: " . print_r($data, true);
    }
    $logEntry .= "\n";
    @file_put_contents($logFile, $logEntry, FILE_APPEND | LOCK_EX);
}

function createDebugResponse($success, $message, $data = [], $debug = []) {
    return [
        'success' => $success,
        'message'  => $message,
        'data'     => $data,
        'debug'    => $debug,
        'timestamp'=> date('Y-m-d H:i:s'),
        'method'   => $_SERVER['REQUEST_METHOD'] ?? 'UNKNOWN'
    ];
}

// =============================
// Utilitários de segurança / normalização
// =============================
function parseSizeToBytes($val) {
    $val = trim((string)$val);
    if ($val === '') return null;
    $last = strtolower(substr($val, -1));
    $num = (float)$val;
    switch ($last) {
        case 'g': $num *= 1024;
        case 'm': $num *= 1024;
        case 'k': $num *= 1024;
    }
    return (int)$num;
}

function startsWith($haystack, $needle) {
    return substr($haystack, 0, strlen($needle)) === $needle;
}

/**
 * Normaliza o subPath para ser SEMPRE diretório.
 * - Remove separadores duplicados e barras no começo/fim.
 * - Se o último segmento "parecer arquivo" (tem extensão) ou for igual ao $fileName, remove.
 * - Remove ocorrências de "./" e "../" (path traversal).
 */
function normalizaSubPathDir(string $subPath, string $fileName = ''): string {
    $rel = trim(str_replace('\\', '/', $subPath), '/');
    if ($rel === '') return '';

    $segments = array_values(array_filter(explode('/', $rel), function($seg) {
        return $seg !== '' && $seg !== '.';
    }));

    // remove path traversal ".."
    $safe = [];
    foreach ($segments as $seg) {
        if ($seg === '..') {
            if (!empty($safe)) array_pop($safe);
            continue;
        }
        $safe[] = $seg;
    }

    if (empty($safe)) return '';

    $last = end($safe);

    // Heurística: se último "parece arquivo" (tem .ext) OU é o próprio nome do arquivo, remove.
    if ($last === $fileName || preg_match('/\.[A-Za-z0-9]{1,8}$/', $last)) {
        array_pop($safe);
    }

    $rel = implode('/', $safe);
    return $rel; // já sem barras nas pontas
}

/** Garante que um caminho relativo final permaneça dentro de uma base */
function assertPathInsideBase($baseDir, $targetDir) {
    $baseReal   = rtrim(realpath($baseDir) ?: $baseDir, '/');
    $targetReal = rtrim(realpath($targetDir) ?: $targetDir, '/');

    if (!file_exists($targetDir)) {
        return startsWith($targetDir, $baseReal);
    }
    return startsWith($targetReal, $baseReal);
}

/** Normaliza strings de pasta vindas do cliente (\/, \\ etc.) */
function normalizeFolderString(string $s): string {
    $s = str_replace(['\\/', '\\\\'], '/', $s);
    $s = str_replace('\\', '/', $s);
    $s = trim($s);
    $s = preg_replace('#/+#', '/', $s);
    return trim($s, '/');
}

/**
 * Resolve a pasta aceita pelo servidor a partir de:
 *  - KEY (rótulo) do JSON de permissões, ou
 *  - VALUE relativo, ou
 *  - caminho absoluto/relativo (com ou sem barras escapadas)
 * Retorna a KEY correspondente dentro de $map (key => caminho_absoluto) ou null.
 */

function resolveFolderKey(string $input, array $map): ?string {
    global $diretorioBase;
    $needle = normalizeFolderString($input);
    $baseNorm = normalizeFolderString(rtrim($diretorioBase, '/'));

    debugLog('resolveFolderKey', [
        'input' => $input, 
        'normalized' => $needle, 
        'base' => $baseNorm, 
        'map_keys' => array_keys($map)
    ]);

    foreach ($map as $key => $absPath) {
        $normKey   = normalizeFolderString($key);
        $normValue = normalizeFolderString($absPath);

        // 1) Coincidência exata com a key (rótulo)
        if ($needle === $normKey) {
            debugLog('resolveFolderKey - match exato com key', ['key' => $normKey]);
            return $key;
        }

        // 2) Coincidência exata com o absoluto retornado
        if ($needle === $normValue) {
            debugLog('resolveFolderKey - match exato com value', ['value' => $normValue]);
            return $key;
        }

        // 3) Coincidência com o relativo extraído do absoluto
        $relFromAbs = ltrim(preg_replace('#^'.preg_quote($baseNorm,'#').'/?#','',$normValue), '/');
        if ($needle === normalizeFolderString($relFromAbs)) {
            debugLog('resolveFolderKey - match com relativo', ['relative' => $relFromAbs]);
            return $key;
        }

        // 4) CORREÇÃO CRÍTICA: Verifica se o needle é SUBPASTA da key permitida
        if (strpos($needle, $normKey . '/') === 0) {
            debugLog('resolveFolderKey - subpasta válida da key', [
                'needle' => $needle, 
                'key' => $normKey,
                'is_subpath' => true
            ]);
            return $key;
        }
        
        // 5) CORREÇÃO: Verifica se o needle é SUBPASTA do relativo
        if (strpos($needle, normalizeFolderString($relFromAbs) . '/') === 0) {
            debugLog('resolveFolderKey - subpasta válida do relativo', [
                'needle' => $needle, 
                'relative' => $relFromAbs,
                'is_subpath' => true
            ]);
            return $key;
        }
    }
    
    debugLog('resolveFolderKey - nenhum match encontrado', ['needle' => $needle]);
    return null;
}

// =============================
// Funções de Permissões
// =============================

function carregarPermissoes() {
    global $permissionsFile;

    if (!file_exists($permissionsFile)) {
        $msg = "Arquivo de permissões não encontrado: $permissionsFile";
        debugLog($msg);
        throw new RuntimeException($msg);
    }

    $content = @file_get_contents($permissionsFile);
    if ($content === false || trim($content) === '') {
        $msg = "Arquivo de permissões vazio ou inacessível: $permissionsFile";
        debugLog($msg);
        throw new RuntimeException($msg);
    }

    $permissions = json_decode($content, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        $msg = "JSON inválido em $permissionsFile: " . json_last_error_msg();
        debugLog($msg);
        throw new RuntimeException($msg);
    }

    // validações mínimas de estrutura
    if (!isset($permissions['users']) || !is_array($permissions['users'])) {
        throw new RuntimeException("Campo 'users' ausente ou inválido em user_permissions.json");
    }
    if (!isset($permissions['allowed_extensions']) || !is_array($permissions['allowed_extensions']) || empty($permissions['allowed_extensions'])) {
        throw new RuntimeException("Campo 'allowed_extensions' ausente/inesperado em user_permissions.json");
    }
    if (!isset($permissions['config']) || !is_array($permissions['config'])) {
        throw new RuntimeException("Campo 'config' ausente ou inválido em user_permissions.json");
    }
    if (empty($permissions['config']['max_file_size'])) {
        throw new RuntimeException("Campo 'config.max_file_size' ausente em user_permissions.json");
    }

    $content = @file_get_contents($permissionsFile);
    $permissions = json_decode($content, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        debugLog("Erro ao decodificar JSON de permissões", json_last_error_msg());
        return ['users' => [], 'allowed_extensions' => [], 'config' => []];
    }
    return $permissions;
}

function obterPastasUsuario($userId) {
    global $diretorioBase;

    $permissions = carregarPermissoes();
    $userConfig  = $permissions['users'][$userId] ?? null;

    if (!$userConfig || empty($userConfig['folders'])) {
        debugLog("Usuário $userId não encontrado ou sem pastas configuradas");
        return [];
    }

    $pastasFormatadas = [];
    foreach ($userConfig['folders'] as $nome => $caminho) {
        // Retorna caminho ABSOLUTO (base + value)
        $caminhoCompleto = rtrim($diretorioBase, '/') . '/' . ltrim($caminho, '/\\');
        $pastasFormatadas[$nome] = $caminhoCompleto;
    }

    debugLog("Pastas obtidas para usuário $userId", [
        'base_directory'    => $diretorioBase,
        'formatted_folders' => $pastasFormatadas
    ]);
    return $pastasFormatadas;
}

function obterExtensoesPermitidas() {
    $permissions = carregarPermissoes();

    if (!isset($permissions['allowed_extensions'])) {
        throw new Exception("Configuração 'allowed_extensions' ausente no arquivo de permissões.");
    }
    return $permissions['allowed_extensions'];
}

function obterConfiguracao() {
    $permissions = carregarPermissoes();

    if (!isset($permissions['config'])) {
        throw new Exception("Configuração 'config' ausente no arquivo de permissões.");
    }
    return $permissions['config'];
}

function verificaECriaDiretorio($dir) {
    if (!is_dir($dir)) {
        $result = @mkdir($dir, 0777, true);
        if ($result) { @chmod($dir, 0777); }
        return $result;
    }
    return true;
}

// Excluir pasta recursivamente
function excluirPastaRecursiva($dir) {
    if (!is_dir($dir)) {
        debugLog("Diretório não existe para exclusão", ['dir' => $dir]);
        return false;
    }

    try {
        $iterator = new RecursiveDirectoryIterator($dir, RecursiveDirectoryIterator::SKIP_DOTS);
        $files    = new RecursiveIteratorIterator($iterator, RecursiveIteratorIterator::CHILD_FIRST);

        foreach ($files as $file) {
            if ($file->isDir()) {
                @rmdir($file->getRealPath());
                debugLog("Diretório removido", ['path' => $file->getRealPath()]);
            } else {
                @unlink($file->getRealPath());
                debugLog("Arquivo removido", ['path' => $file->getRealPath()]);
            }
        }

        $result = @rmdir($dir);
        debugLog("Exclusão de pasta", ['dir' => $dir, 'success' => $result]);
        return $result;

    } catch (Exception $e) {
        debugLog("Erro ao excluir pasta", ['dir' => $dir, 'error' => $e->getMessage()]);
        return false;
    }
}

function usuarioTemPermissaoExclusao($userId) {
    $permissions = carregarPermissoes();
    $userConfig  = $permissions['users'][$userId] ?? null;
    
    return $userConfig && isset($userConfig['can_delete']) && $userConfig['can_delete'] === true;
}

// =============================
// Autenticação JWT
// =============================
function obterTokenJWT() {
    if (isset($_COOKIE['jwt_user'])) {
        return $_COOKIE['jwt_user'];
    }
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    if (isset($headers['Authorization'])) {
        $authHeader = $headers['Authorization'];
        if (preg_match('/Bearer\s+(.*)$/i', $authHeader, $matches)) {
            return $matches[1];
        }
    }
    return null;
}

function obterInfoUsuario($token) {
    if (empty($token)) return null;

    $url = 'https://db33.dev.dinabox.net/api/dinabox/system/users/user';
    $ch  = curl_init($url);

    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $token,
        'Content-Type: application/json'
    ]);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 5);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error    = curl_error($ch);
    curl_close($ch);

    debugLog("Verificação de usuário", [
        'token_preview'   => substr($token, 0, 20) . '...',
        'http_code'       => $httpCode,
        'curl_error'      => $error,
        'response_preview'=> substr($response, 0, 200)
    ]);

    if ($httpCode == 200 && !empty($response)) {
        $userData = json_decode($response, true);
        if (json_last_error() === JSON_ERROR_NONE && isset($userData['id'])) {
            return $userData;
        }
    }
    return null;
}

function verificarAutenticacao() {
    $token = obterTokenJWT();
    if (!$token) {
        debugLog("Token não encontrado");
        return [false, null, "Token JWT não encontrado"];
    }

    $userInfo = obterInfoUsuario($token);
    if (!$userInfo || !isset($userInfo['id'])) {
        debugLog("Falha na verificação do usuário", ['token_preview' => substr($token, 0, 20) . '...']);
        return [false, null, "Token inválido ou expirado"];
    }

    $userId          = $userInfo['id'];
    $pastasDoUsuario = obterPastasUsuario($userId);

    if (empty($pastasDoUsuario)) {
        debugLog("Usuário sem pastas configuradas", ['user_id' => $userId]);
        return [false, $userId, "Usuário não tem permissões configuradas"];
    }

    debugLog("Autenticação bem-sucedida", [
        'user_id'       => $userId,
        'pastas_count'  => count($pastasDoUsuario)
    ]);

    return [true, $userId, null, $pastasDoUsuario];
}

function autenticarUsuario($username, $password) {
    $url = 'https://db33.dev.dinabox.net/api/dinabox/system/users/auth';
    $ch  = curl_init();

    curl_setopt_array($ch, array(
        CURLOPT_URL => $url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_ENCODING => '',
        CURLOPT_MAXREDIRS => 10,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_HTTP_VERSION => CURL_HTTP_VERSION_1_1,
        CURLOPT_CUSTOMREQUEST => 'POST',
        CURLOPT_POSTFIELDS => array(
            'username' => $username,
            'password' => $password
        )
        
    ));

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error    = curl_error($ch);
    curl_close($ch);

    debugLog("Tentativa de login", [
        'username'          => $username,
        'http_code'         => $httpCode,
        'curl_error'        => $error,
        'request_url'       => $_SERVER['REQUEST_URI'] ?? '',
        'response_preview'  => substr($response, 0, 200)
    ]);

    if ($httpCode == 200 && !empty($response)) {
        $authData = json_decode($response, true);
        if (json_last_error() === JSON_ERROR_NONE && isset($authData['token'])) {
            return [true, $authData];
        }
    }
    return [false, null];
}

// =============================
// Listagem
// =============================
function listarArquivosPasta($caminhoCompleto) {
    debugLog("Listando arquivos", ['caminho_completo' => $caminhoCompleto]);

    if (!is_dir($caminhoCompleto)) {
        debugLog("Diretório não existe: $caminhoCompleto");
        return [];
    }

    $arquivos = [];
    try {
        $iterator = new DirectoryIterator($caminhoCompleto);
        foreach ($iterator as $item) {
            if ($item->isDot()) continue;
            $arquivos[] = [
                'name'     => $item->getFilename(),
                'type'     => $item->isDir() ? 'directory' : 'file',
                'size'     => $item->isFile() ? $item->getSize() : 0,
                'modified' => date('Y-m-d H:i:s', $item->getMTime())
            ];
        }
        usort($arquivos, function($a, $b) {
            if ($a['type'] !== $b['type']) {
                return $a['type'] === 'directory' ? -1 : 1;
            }
            return strcasecmp($a['name'], $b['name']);
        });
    } catch (Exception $e) {
        debugLog("Erro ao listar arquivos", ['erro' => $e->getMessage()]);
        return [];
    }
    debugLog("Arquivos listados com sucesso", ['total' => count($arquivos)]);
    return $arquivos;
}

// Tradução de erros de upload
function traduzErroUpload($error) {
    switch ($error) {
        case UPLOAD_ERR_OK:        return 'Upload realizado com sucesso';
        case UPLOAD_ERR_INI_SIZE:  return 'Arquivo muito grande (upload_max_filesize)';
        case UPLOAD_ERR_FORM_SIZE: return 'Arquivo muito grande (MAX_FILE_SIZE)';
        case UPLOAD_ERR_PARTIAL:   return 'Upload parcial';
        case UPLOAD_ERR_NO_FILE:   return 'Nenhum arquivo enviado';
        case UPLOAD_ERR_NO_TMP_DIR:return 'Pasta temporária ausente';
        case UPLOAD_ERR_CANT_WRITE:return 'Falha ao escrever no disco';
        case UPLOAD_ERR_EXTENSION: return 'Upload bloqueado por extensão';
        default:                   return "Erro desconhecido: $error";
    }
}

// =============================
// INÍCIO DO PROCESSAMENTO PRINCIPAL
// =============================
try {
    // =============================
    // Login via API real
    // =============================
    if (isset($_POST['action']) && $_POST['action'] === 'login') {
        $username = $_POST['username'] ?? '';
        $password = $_POST['password'] ?? '';

        if (empty($username) || empty($password)) {
            echo json_encode(createDebugResponse(false, 'Username e password são obrigatórios', [], [
                'required_fields' => ['username','password']
            ]), JSON_PRETTY_PRINT);
            exit;
        }

        debugLog("Iniciando processo de login", ['username' => $username]);
        list($success, $authData) = autenticarUsuario($username, $password);

        if ($success && $authData) {
            $userId          = $authData['id'] ?? null;
            $pastasDoUsuario = $userId ? obterPastasUsuario($userId) : [];
            $authData['folders']         = array_keys($pastasDoUsuario);
            $authData['folders_count']   = count($pastasDoUsuario);
            $authData['has_permissions'] = !empty($pastasDoUsuario);
            $authData['can_delete']      = usuarioTemPermissaoExclusao($userId);
            echo json_encode($authData, JSON_PRETTY_PRINT);
        } else {
            debugLog("Falha no login", ['username' => $username,'auth_success' => false]);
            echo json_encode(createDebugResponse(false, 'Credenciais inválidas', [], [
                'username'      => $username,
                'auth_endpoint' => 'https://db33.dev.dinabox.net/api/dinabox/system/users/auth'
            ]), JSON_PRETTY_PRINT);
        }
        exit;
    }

    // =============================
    // Status da API (GET) - sem auth
    // =============================
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        echo json_encode(createDebugResponse(true, 'API UPLOAD pronta', [
            'version'     => '3.2',
            'timestamp'   => date('Y-m-d H:i:s'),
            'endpoints'   => ['upload','list','update_folders'],
            'auth_methods'=> ['JWT Cookie (jwt_user)', 'JWT Header (Authorization: Bearer)']
        ]), JSON_PRETTY_PRINT);
        exit;
    }

    // =============================
    // Verificar autenticação para POST
    // =============================
    $authResult      = verificarAutenticacao();
    $isAuthenticated = $authResult[0];
    $userId          = $authResult[1];
    $authError       = $authResult[2];
    $pastasDoUsuario = $authResult[3] ?? [];

    if (!$isAuthenticated) {
        echo json_encode(createDebugResponse(false, $authError ?? 'Não autenticado', [], [
            'user_id'      => $userId,
            'auth_required'=> true,
            'auth_methods' => [
                'Cookie: jwt_user (obtido via login no sistema principal)',
                'Header: Authorization: Bearer <token>'
            ]
        ]), JSON_PRETTY_PRINT);
        exit;
    }

    // =============================
    // Endpoint de Listagem
    // =============================

    if (isset($_POST['action']) && $_POST['action'] === 'get_correct_paths') {
        $correctPaths = [];
        foreach ($pastasDoUsuario as $absolutePath) {
            $relativePath = ltrim(str_replace($diretorioBase, '', $absolutePath), '/');
            $correctPaths[] = str_replace('/', '\/', $relativePath);
        }
        
        echo json_encode([
            'success' => true,
            'correct_paths' => $correctPaths
        ]);
        exit;
    }


if (isset($_POST['action']) && $_POST['action'] === 'list') {
    $caminho = $_POST['path'] ?? '';

    debugLog("Requisição de listagem", ['user_id' => $userId,'caminho' => $caminho]);

    if (empty($caminho)) {
        echo json_encode(createDebugResponse(false, 'Caminho é obrigatório', [], [
            'parameter_required' => 'path',
            'example' => 'T3/projeto/assets',
            'available_folders' => array_keys($pastasDoUsuario)
        ]), JSON_PRETTY_PRINT);
        exit;
    }

    // Normalizar o caminho antes de quebrar em partes
    $caminhoNormalizado = normalizeFolderString($caminho);
    debugLog('Caminho normalizado', ['original' => $caminho, 'normalizado' => $caminhoNormalizado]);

    // SEMPRE separar em pasta raiz e subcaminho primeiro
    $pathParts  = explode('/', $caminhoNormalizado);
    $pastaRaiz  = $pathParts[0];
    $subCaminho = implode('/', array_slice($pathParts, 1));

    debugLog('Separação inicial', ['root_folder' => $pastaRaiz, 'sub_path' => $subCaminho]);

    // ESTRATÉGIA 1: Tentar resolver a pasta raiz apenas
    $resolvedKey = resolveFolderKey($pastaRaiz, $pastasDoUsuario);
    
    if ($resolvedKey !== null) {
        // SUCESSO: Encontrou a pasta raiz
        $caminhoBase = rtrim($pastasDoUsuario[$resolvedKey], '/');
        $relDir = normalizaSubPathDir($subCaminho, '');
        $caminhoCompleto = $caminhoBase . ($relDir !== '' ? '/' . $relDir : '');
        
        debugLog('Estratégia 1 - Sucesso (pasta raiz)', [
            'resolved_key' => $resolvedKey,
            'base_path' => $caminhoBase,
            'relative_dir' => $relDir,
            'full_path' => $caminhoCompleto
        ]);
        
    } else {
        // ESTRATÉGIA 2: Tentar resolver o caminho completo (fallback para machine-settings)
        debugLog('Estratégia 1 falhou, tentando caminho completo');
        
        $resolvedKey = resolveFolderKey($caminhoNormalizado, $pastasDoUsuario);
        
        if ($resolvedKey !== null) {
            // SUCESSO: Encontrou match com caminho completo
            $caminhoBase = rtrim($pastasDoUsuario[$resolvedKey], '/');
            $relDir = ''; // Sem subcaminho quando match é completo
            $caminhoCompleto = $caminhoBase;
            
            debugLog('Estratégia 2 - Sucesso (caminho completo)', [
                'resolved_key' => $resolvedKey,
                'base_path' => $caminhoBase,
                'full_path' => $caminhoCompleto
            ]);
            
        } else {
            // FALHA TOTAL: Não encontrou nada
            echo json_encode(createDebugResponse(false, 'Caminho inválido', [], [
                'requested_path' => $caminho,
                'normalized_path' => $caminhoNormalizado,
                'root_folder' => $pastaRaiz,
                'sub_path' => $subCaminho,
                'available_folders' => array_keys($pastasDoUsuario),
                'strategy_1_tried' => $pastaRaiz,
                'strategy_2_tried' => $caminhoNormalizado
            ]), JSON_PRETTY_PRINT);
            exit;
        }
    }

    debugLog('Caminho final para listagem', [
        'resolved_key' => $resolvedKey,
        'base_path' => $caminhoBase,
        'relative_path' => $relDir ?? 'N/A',
        'full_path' => $caminhoCompleto
    ]);

    if (!assertPathInsideBase($caminhoBase, $caminhoCompleto)) {
        echo json_encode(createDebugResponse(false, 'Caminho inválido', [], [
            'reason' => 'path outside base'
        ]), JSON_PRETTY_PRINT);
        exit;
    }

    $arquivos = listarArquivosPasta($caminhoCompleto);

    echo json_encode(createDebugResponse(true, 'Listagem realizada com sucesso', [
        'path' => $caminho,
        'normalized_path' => $caminhoNormalizado,
        'full_path' => $caminhoCompleto,
        'items' => $arquivos,
        'total_items' => count($arquivos)
    ]), JSON_PRETTY_PRINT);
    exit;
}

    // =============================
    // Atualizar Pastas
    // =============================
    if (isset($_POST['action']) && $_POST['action'] === 'update_folders') {
        debugLog("Pastas atualizadas para usuário", ['user_id' => $userId,'pastas' => array_keys($pastasDoUsuario)]);
        echo json_encode(createDebugResponse(true, 'Pastas carregadas com sucesso', [
            'folders'       => array_keys($pastasDoUsuario),
            'total_folders' => count($pastasDoUsuario),
            'user_id'       => $userId
        ]), JSON_PRETTY_PRINT);
        exit;
    }

    // =============================
    // Upload de Arquivos
    // =============================
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($_POST['action'])) {

        $pastaEscolhida = $_POST['pasta'] ?? '';
        $withDelete     = isset($_POST['with_delete']) && $_POST['with_delete'] === 'true';
        $subPath        = $_POST['path'] ?? '';

        $config        = obterConfiguracao();
        $maxSizeBytes  = isset($config['max_file_size']) ? parseSizeToBytes($config['max_file_size']) : null;

        debugLog("Upload request", [
            'folder'       => $pastaEscolhida,
            'files_count'  => count($_FILES),
            'post_data'    => array_keys($_POST),
            'user_id'      => $userId,
            'with_delete'  => $withDelete,
            'sub_path_raw' => $subPath
        ]);

        // resolve pasta tolerante (key/value/escapes)
        $resolvedKey = resolveFolderKey(normalizeFolderString($pastaEscolhida), $pastasDoUsuario);
        if ($resolvedKey === null) {
            echo json_encode(createDebugResponse(false, 'Pasta inválida', [], [
                'requested_folder' => $pastaEscolhida,
                'available_folders'=> array_keys($pastasDoUsuario)
            ]), JSON_PRETTY_PRINT);
            exit;
        }
        $destinoBase = rtrim($pastasDoUsuario[$resolvedKey], '/');

        // Exclusão opcional
        $deleteResult = null;
        if ($withDelete) {
            if (!usuarioTemPermissaoExclusao($userId)) {
                echo json_encode(createDebugResponse(false, 'Usuário não tem permissão para exclusão', [], [
                    'user_id'              => $userId,
                    'can_delete'           => false,
                    'with_delete_requested'=> true
                ]), JSON_PRETTY_PRINT);
                exit;
            }

            $relDirDelete   = normalizaSubPathDir($subPath, '');
            //$pastaParaExcluir = $destinoBase . ($relDirDelete !== '' ? '/' . $relDirDelete : '');
            $pastaParaExcluir = $destinoBase;


            debugLog("Iniciando exclusão de pasta", [
                'pasta_para_excluir' => $pastaParaExcluir,
                'user_id'            => $userId,
                'sub_path_norm'      => $relDirDelete
            ]);

            if (!assertPathInsideBase($destinoBase, $pastaParaExcluir)) {
                echo json_encode(createDebugResponse(false, 'Caminho de exclusão inválido'), JSON_PRETTY_PRINT);
                exit;
            }

            if (is_dir($pastaParaExcluir)) {
                $deleteResult = excluirPastaRecursiva($pastaParaExcluir);
                if (!$deleteResult) {
                    echo json_encode(createDebugResponse(false, 'Falha ao excluir pasta antes do upload', [
                        'delete_attempted' => true,
                        'delete_success'   => false,
                        'target_folder'    => $pastaParaExcluir
                    ]), JSON_PRETTY_PRINT);
                    exit;
                }
                debugLog("Pasta excluída com sucesso", ['pasta_excluida' => $pastaParaExcluir,'user_id' => $userId]);
            } else {
                debugLog("Pasta não existe para exclusão", ['pasta_para_excluir' => $pastaParaExcluir]);
                $deleteResult = true;
            }
        }

        verificaECriaDiretorio($destinoBase);

        // Normalizar lista de arquivos do POST
        $arquivos = [];
        foreach ($_FILES as $field => $file) {
            if (is_array($file['name'])) {
                foreach ($file['name'] as $i => $n) {
                    if (!empty($n)) {
                        $arquivos[] = [
                            'name'  => $n,
                            'tmp'   => $file['tmp_name'][$i],
                            'error' => $file['error'][$i],
                            'size'  => $file['size'][$i],
                            'field' => $field
                        ];
                    }
                }
            } else if (!empty($file['name'])) {
                $arquivos[] = [
                    'name'  => $file['name'],
                    'tmp'   => $file['tmp_name'],
                    'error' => $file['error'],
                    'size'  => $file['size'],
                    'field' => $field
                ];
            }
        }

        debugLog("Arquivos recebidos para upload", ['count' => count($arquivos), 'files' => array_column($arquivos, 'name')]);

        $extensoesPermitidas = obterExtensoesPermitidas();
        $uploaded = [];
        $failed   = [];

        foreach ($arquivos as $f) {
            $ext = strtolower(pathinfo($f['name'], PATHINFO_EXTENSION));
            if (!in_array($ext, $extensoesPermitidas)) {
                $failed[] = ['arquivo' => $f['name'], 'erro' => "Extensão .$ext não permitida"];
                debugLog("Extensão não permitida", ['file' => $f['name'], 'extension' => $ext]);
                continue;
            }

            // $maxSizeBytes agora representa o limite em MB, então convertemos para bytes
            if ($maxSizeBytes && (int)$f['size'] > ($maxSizeBytes * 1024 * 1024)) {
                $failed[] = ['arquivo' => $f['name'], 'erro' => "Arquivo excede o limite ({$config['max_file_size']} MB)"];
                debugLog("Arquivo grande demais", ['file' => $f['name'], 'size' => $f['size'], 'max_bytes' => $maxSizeBytes * 1024 * 1024]);
                continue;
            }

            // path sempre diretório
            $relDir    = normalizaSubPathDir($subPath, $f['name']);
            $targetDir = $destinoBase . ($relDir !== '' ? '/' . $relDir : '');

            if (!assertPathInsideBase($destinoBase, $targetDir)) {
                $failed[] = ['arquivo' => $f['name'], 'erro' => "Caminho inválido"];
                debugLog("Path fora da base detectado", ['targetDir' => $targetDir]);
                continue;
            }

            if (!is_dir($targetDir)) {
                $created = @mkdir($targetDir, 0777, true);
                if ($created) { @chmod($targetDir, 0777); }
                debugLog("Criando diretório", ['dir' => $targetDir, 'success' => $created]);
            }

            if ($f['error'] !== UPLOAD_ERR_OK) {
                $failed[] = ['arquivo' => $f['name'], 'erro' => traduzErroUpload($f['error'])];
                debugLog("Erro no upload", ['file' => $f['name'], 'error' => $f['error']]);
                continue;
            }

            $destino      = $targetDir . '/' . $f['name'];
            $relativePath = ($relDir !== '' ? $relDir . '/' : '') . $f['name'];

            if (@move_uploaded_file($f['tmp'], $destino)) {
                @chmod($destino, 0666);
                $uploaded[] = [
                    'name'          => $f['name'],
                    'size'          => $f['size'],
                    'relative_path' => $relativePath,
                    'full_path'     => $destino
                ];
                debugLog("Arquivo enviado com sucesso", ['file' => $f['name'], 'destination' => $destino]);
            } else {
                $failed[] = ['arquivo' => $f['name'], 'erro' => "Falha ao mover arquivo"];
                debugLog("Falha no move_uploaded_file", ['file' => $f['name'], 'destination' => $destino]);
            }
        }

        $success = !empty($uploaded) && empty($failed);
        $message = "Upload concluído. Sucesso: " . count($uploaded) . ", Falhas: " . count($failed);

        if ($withDelete && $deleteResult !== null) {
            $message .= ". Pasta excluída antes do upload.";
        }

        $responseData = [
            'uploaded'       => $uploaded,
            'failed'         => $failed,
            'uploaded_count' => count($uploaded),
            'failed_count'   => count($failed)
        ];

        if ($withDelete) {
            $responseData['delete_operation'] = [
                'requested'           => true,
                'success'             => $deleteResult,
                'user_has_permission' => usuarioTemPermissaoExclusao($userId)
            ];
        }

        echo json_encode(createDebugResponse($success, $message, $responseData), JSON_PRETTY_PRINT);
        exit;
    }

    // =============================
    // Fallback - Status autenticado
    // =============================
    echo json_encode(createDebugResponse(true, 'API UPLOAD autenticada', [
        'user_id'       => $userId,
        'folders'       => array_keys($pastasDoUsuario),
        'folders_count' => count($pastasDoUsuario)
    ], [
        'available_actions' => ['list','update_folders','upload'],
        'authenticated_via' => 'JWT API'
    ]), JSON_PRETTY_PRINT);

} catch (Exception $e) {
    debugLog("Erro fatal", [
        'message' => $e->getMessage(),
        'file'    => $e->getFile(),
        'line'    => $e->getLine(),
        'trace'   => $e->getTraceAsString()
    ]);

    echo json_encode([
        'success' => false,
        'message' => 'Erro interno do servidor',
        'error'   => $e->getMessage(),
        'debug'   => [
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ]
    ], JSON_PRETTY_PRINT);
}