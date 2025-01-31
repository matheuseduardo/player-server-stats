CREATE TABLE IF NOT EXISTS `players` (
    id        INTEGER      PRIMARY KEY AUTOINCREMENT,
    steamid   STRING (64)  NOT NULL, 
    name      STRING (64), 
    birthday  NUMERIC,
    nick      STRING (128) NOT NULL, 
    lasttime  NUMERIC      NOT NULL,
    total_time INTEGER     DEFAULT 0 -- Tempo total conectado em segundos
);
