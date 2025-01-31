CREATE TABLE IF NOT EXISTS `players` (
    id        INTEGER      PRIMARY KEY AUTOINCREMENT,
    steamid   STRING (64)  NOT NULL, 
    name      STRING (64), 
    birthday  NUMERIC,
    nick      STRING (128) NOT NULL, 
    lasttime  NUMERIC      NOT NULL,
    total_time INTEGER     DEFAULT 0 -- Tempo total conectado em segundos
);

CREATE TABLE IF NOT EXISTS `sessions` (
    id         INTEGER      PRIMARY KEY AUTOINCREMENT,
    player_id  INTEGER      NOT NULL, -- ID do jogador na tabela 'players'
    start_time NUMERIC      NOT NULL, -- Timestamp de início da sessão
    end_time   NUMERIC,               -- Timestamp de fim da sessão (NULL se ainda conectado)
    duration   INTEGER      DEFAULT 0 -- Duração da sessão em segundos
);