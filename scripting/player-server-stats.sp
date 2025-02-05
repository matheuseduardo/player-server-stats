#define INVALID_PLAYER_ID -1

#include <sourcemod>
#include <sdktools>
#include <dbi>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "Player Server Stats",
    author = "@matheuseduardo",
    description = "Registra estatísticas dos jogadores no servidor usando SQLite.",
    version = "v0.1",
    url = "https://matheuseduardo.dev"
};

// Handle para a conexão com o banco de dados
Handle g_hDatabase = INVALID_HANDLE;

// ConVar para definir o limite de tempo (em segundos)
ConVar g_cvarReconnectThreshold;

// Função chamada quando o plugin é carregado
public void OnPluginStart()
{
    // Registra a ConVar
    g_cvarReconnectThreshold = CreateConVar("sm_reconnect_threshold", "30", "Tempo máximo (em segundos) para considerar uma reconexão rápida.");

    char error[256];
    g_hDatabase = SQLite_UseDatabase("player_stats.db", error, sizeof(error));
    if (g_hDatabase == INVALID_HANDLE)
    {
        SetFailState("Falha ao abrir o banco de dados SQLite: %s", error);
        return;
    }

    SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS `players` ( \
        id        INTEGER      PRIMARY KEY AUTOINCREMENT, \
        steamid   STRING (64)  NOT NULL, \
        nick      STRING (128) NOT NULL, \
        name      STRING (64), \
        birthday  NUMERIC, \
        lasttime  NUMERIC      NOT NULL, \
        total_time INTEGER     DEFAULT 0 \
    );");

    SQL_FastQuery(g_hDatabase, "CREATE TABLE IF NOT EXISTS `sessions` ( \
        id         INTEGER      PRIMARY KEY AUTOINCREMENT, \
        player_id  INTEGER      NOT NULL, \
        start_time NUMERIC      NOT NULL, \
        end_time   NUMERIC, \
        duration   INTEGER      DEFAULT 0 \
    );");
}

// Função chamada quando um jogador se conecta
public void OnClientConnected(int client)
{
    if (IsFakeClient(client)) return; // Ignora bots
    
    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    // Obtém o nome do jogador
    char playerName[64];
    GetClientName(client, playerName, sizeof(playerName));

    // Buffer para mensagens de erro
    char error[256];
    char query[256];
    bool execOk;

    // Verifica se o jogador já está registrado na tabela 'players'
    FormatEx(query, sizeof(query), "SELECT id FROM `players` WHERE steamid = '%s';", steamid);
    DBResultSet results = SQL_Query(g_hDatabase, query);
    int playerId = INVALID_PLAYER_ID;
    if (results != INVALID_HANDLE && results.RowCount > 0)
    {
        playerId = results.FetchInt(0); // Índice 0 para o campo 'id'
        delete results;
    }
    else
    {
        // escapa o nome
        char escapedName[128];
        SQL_EscapeString(g_hDatabase, playerName, escapedName, sizeof(escapedName));
        
        // Jogador não existe, insere na tabela 'players'
        FormatEx(query, sizeof(query), "INSERT INTO `players` (steamid, nick, lasttime, total_time) VALUES ('%s', '%s', %d, 0);", steamid, escapedName, GetTime());
        execOk = SQL_FastQuery(g_hDatabase, query);
        if (!execOk)
        {
            SQL_GetError(g_hDatabase, error, sizeof(error));
            PrintToServer("Falha ao inserir jogador: %s", error);
            return;
        }

        playerId = SQL_GetInsertId(g_hDatabase);
        PrintToServer("[Player Server Stats] Novo jogador registrado com ID %d.", playerId);
    }

    // Verifica a última sessão do jogador
    FormatEx(query, sizeof(query), "SELECT id, end_time FROM `sessions` WHERE player_id = %d ORDER BY start_time DESC LIMIT 1;", playerId);
    results = SQL_Query(g_hDatabase, query);
    if (results != INVALID_HANDLE && results.RowCount > 0)
    {
        int sessionId = results.FetchInt(0); // Índice 0 para o campo 'id'
        int lastEndTime = results.FetchInt(1); // Índice 1 para o campo 'end_time'

        // Obtém o limite de tempo da ConVar
        int threshold = GetConVarInt(g_cvarReconnectThreshold);

        // Se a última desconexão foi recente, reativa a sessão existente
        if (lastEndTime > 0 && GetTime() - lastEndTime <= threshold)
        {
            FormatEx(query, sizeof(query), "UPDATE `sessions` SET end_time = NULL WHERE id = %d;", sessionId);
            execOk = SQL_FastQuery(g_hDatabase, query);
            if (!execOk)
            {
                SQL_GetError(g_hDatabase, error, sizeof(error));
                PrintToServer("Falha ao reativar sessão: %s", error);
                return;
            }

            PrintToServer("[Player Server Stats] Sessão reativada para jogador ID %d.", playerId);
            return;
        }

        delete results;
    }

    // Insere uma nova sessão na tabela 'sessions'
    FormatEx(query, sizeof(query), "INSERT INTO `sessions` (player_id, start_time) VALUES (%d, %d);", playerId, GetTime());
    execOk = SQL_FastQuery(g_hDatabase, query);
    if (!execOk)
    {
        SQL_GetError(g_hDatabase, error, sizeof(error));
        PrintToServer("Falha ao registrar sessão: %s", error);
        return;
    }

    int sessionId = SQL_GetInsertId(g_hDatabase);
    PrintToServer("[Player Server Stats] Nova sessão registrada com ID %d.", sessionId);
}

// Função chamada quando um jogador desconecta
public void OnClientDisconnect(int client)
{
    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    // Obtém o ID do jogador
    char query[256];
    FormatEx(query, sizeof(query), "SELECT id, lasttime FROM `players` WHERE steamid = '%s';", steamid);
    DBResultSet results = SQL_Query(g_hDatabase, query);
    if (results == INVALID_HANDLE || results.RowCount == 0)
    {
        LogError("Erro ao obter jogador: SteamID %s não encontrado.", steamid);
        return;
    }

    int playerId = results.FetchInt(0); // Índice 0 para o campo 'id'
    int lastTime = results.FetchInt(1); // Índice 1 para o campo 'lasttime'

    // Atualiza a sessão mais recente do jogador
    FormatEx(query, sizeof(query), "UPDATE `sessions` SET end_time = %d, duration = %d - start_time WHERE player_id = %d AND end_time IS NULL;",
        GetTime(), GetTime(), playerId);

    bool execOk = SQL_FastQuery(g_hDatabase, query);
    if (!execOk)
    {
        char error[256];
        SQL_GetError(g_hDatabase, error, sizeof(error));
        PrintToServer("Falha ao atualizar sessão: %s", error);
        return;
    }

    // Atualiza o tempo total conectado na tabela 'players'
    FormatEx(query, sizeof(query), "UPDATE `players` SET total_time = total_time + %d WHERE id = %d;",
        GetTime() - lastTime, playerId);

    execOk = SQL_FastQuery(g_hDatabase, query);
    if (!execOk)
    {
        char error[256];
        SQL_GetError(g_hDatabase, error, sizeof(error));
        PrintToServer("Falha ao atualizar tempo total conectado: %s", error);
        return;
    }

    PrintToServer("[Player Server Stats] Sessão e tempo total conectado atualizados para jogador ID %d.", playerId);
}

// Função chamada quando o plugin é descarregado
public void OnPluginEnd()
{
    if (g_hDatabase != INVALID_HANDLE)
    {
        CloseHandle(g_hDatabase);
    }
    PrintToServer("[Player Server Stats] Plugin descarregado.");
}