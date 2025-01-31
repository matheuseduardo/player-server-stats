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

// Função chamada quando o plugin é carregado
public void OnPluginStart()
{
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
        name      STRING (64), \
        birthday  NUMERIC, \
        nick      STRING (128) NOT NULL, \
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
    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));

    // Verifica se o jogador já está registrado na tabela 'players'
    int playerId = INVALID_PLAYER_ID;
    DBResultSet results = SQL_Query(g_hDatabase, "SELECT id FROM `players` WHERE steamid = '%s';", steamid);
    if (results != null && results.RowCount > 0)
    {
        // Jogador já existe, obtém o ID
        playerId = results.FetchInt(0, "id");
    }
    else
    {
        // Jogador não existe, insere na tabela 'players'
        char query[512];
        Format(query, sizeof(query), "INSERT INTO `players` (steamid, name, nick, lasttime, total_time) VALUES ('%s', '%s', '%s', %d, 0);",
            steamid, GetClientName(client), GetClientName(client), GetTime());

        bool execOk = SQL_FastQuery(g_hDatabase, query);
        if (!execOk)
        {
            char error[256];
            SQL_GetError(g_hDatabase, error, sizeof(error));
            PrintToServer("Falha ao inserir jogador: %s", error);
            return;
        }

        playerId = SQL_GetInsertId(g_hDatabase);
        PrintToServer("[Player Server Stats] Novo jogador registrado com ID %d.", playerId);
    }

    // Insere uma nova sessão na tabela 'sessions'
    char query[512];
    Format(query, sizeof(query), "INSERT INTO `sessions` (player_id, start_time) VALUES (%d, %d);", playerId, GetTime());

    bool execOk = SQL_FastQuery(g_hDatabase, query);
    if (!execOk)
    {
        char error[256];
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
    DBResultSet results = SQL_Query(g_hDatabase, "SELECT id FROM `players` WHERE steamid = '%s';", steamid);
    if (results == null || results.RowCount == 0)
    {
        LogError("Erro ao obter jogador: SteamID %s não encontrado.", steamid);
        return;
    }

    int playerId = results.FetchInt(0, "id");

    // Atualiza a sessão mais recente do jogador
    char query[512];
    Format(query, sizeof(query), "UPDATE `sessions` SET end_time = %d, duration = %d - start_time WHERE player_id = %d AND end_time IS NULL;",
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
    Format(query, sizeof(query), "UPDATE `players` SET total_time = total_time + %d WHERE id = %d;",
        GetTime() - results.FetchInt(0, "lasttime"), playerId);

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