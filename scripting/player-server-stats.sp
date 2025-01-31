// Nome do Plugin: Player Server Stats
// Descrição: Registra estatísticas dos jogadores no servidor usando SQLite.
// Autor: Seu Nome
// Versão: 1.0

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
    // Buffer para armazenar mensagens de erro
    char error[256];

    // Abre a conexão com o banco de dados SQLite
    g_hDatabase = SQLite_UseDatabase("player_stats.db", error, sizeof(error));
    if (g_hDatabase == INVALID_HANDLE)
    {
        SetFailState("Falha ao abrir o banco de dados SQLite: %s", error);
        return;
    }

    // Cria a tabela 'players' se ela ainda não existir
    SQL_TQuery(g_hDatabase, CreateTableCallback, "CREATE TABLE IF NOT EXISTS `players` ( \
        id        INTEGER      PRIMARY KEY AUTOINCREMENT, \
        steamid   STRING (64)  NOT NULL, \
        name      STRING (64), \
        birthday  NUMERIC, \
        nick      STRING (128) NOT NULL, \
        lasttime  NUMERIC      NOT NULL \
    );");
}

// Callback chamada após a tentativa de criar a tabela
public void CreateTableCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (results == null)
    {
        LogError("Erro ao criar a tabela 'players': %s", error);
        return;
    }

    PrintToServer("[Player Server Stats] Tabela 'players' criada ou já existe.");
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