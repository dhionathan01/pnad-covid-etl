/* =============================================================================
   Arquivo  : 01_auditoria/01_tabela_log_execucao.sql
   Objetivo : Tabela única de log para todas as etapas do ETL.

   Cada execução de procedure abre uma linha (EM EXECUCAO) e fecha a mesma
   linha no final com contagens, status e observação. Se a procedure cair no
   meio, a linha fica registrada com status ERRO e a mensagem do SQL Server.
   ============================================================================= */
USE PNAD_COVID;
GO

IF OBJECT_ID(N'auditoria.log_execucao', N'U') IS NULL
BEGIN
    CREATE TABLE auditoria.log_execucao
    (
        id_log              INT IDENTITY(1, 1) NOT NULL,
        no_processo         VARCHAR(100)       NOT NULL,  -- procedure que executou
        ds_arquivo          NVARCHAR(400)      NULL,      -- CSV lido (só na carga da staging)
        dt_inicio           DATETIME2(0)       NOT NULL CONSTRAINT df_log_execucao_dt_inicio DEFAULT (SYSDATETIME()),
        dt_fim              DATETIME2(0)       NULL,
        qt_linhas_lidas     INT                NULL,
        qt_linhas_gravadas  INT                NULL,
        st_execucao         VARCHAR(20)        NOT NULL CONSTRAINT df_log_execucao_status DEFAULT ('EM EXECUCAO'),
        ds_observacao       VARCHAR(2000)      NULL,
        no_usuario          NVARCHAR(128)      NOT NULL CONSTRAINT df_log_execucao_usuario DEFAULT (SUSER_SNAME()),

        CONSTRAINT pk_log_execucao PRIMARY KEY CLUSTERED (id_log),
        CONSTRAINT ck_log_execucao_status CHECK (st_execucao IN ('EM EXECUCAO', 'SUCESSO', 'SUCESSO PARCIAL', 'ERRO'))
    );

    PRINT 'Tabela auditoria.log_execucao criada.';
END
GO
