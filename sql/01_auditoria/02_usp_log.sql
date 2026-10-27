/* =============================================================================
   Arquivo  : 01_auditoria/02_usp_log.sql
   Objetivo : Procedures para abrir e fechar uma linha de log.

   Por que procedures e não INSERT/UPDATE direto em cada carga?
     Centraliza o formato do log. Se amanhã o log ganhar uma coluna, muda
     aqui e todas as cargas passam a preencher.

   Importante: o log é gravado FORA da transação da carga. Assim, quando a
   carga dá ROLLBACK, o registro do erro continua no log.
   ============================================================================= */
USE PNAD_COVID;
GO

CREATE OR ALTER PROCEDURE auditoria.usp_log_iniciar
    @no_processo VARCHAR(100),
    @ds_arquivo  NVARCHAR(400) = NULL,
    @id_log      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO auditoria.log_execucao (no_processo, ds_arquivo)
    VALUES (@no_processo, @ds_arquivo);

    SET @id_log = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE auditoria.usp_log_finalizar
    @id_log              INT,
    @qt_linhas_lidas     INT          = NULL,
    @qt_linhas_gravadas  INT          = NULL,
    @st_execucao         VARCHAR(20),
    @ds_observacao       VARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE auditoria.log_execucao
       SET dt_fim             = SYSDATETIME(),
           qt_linhas_lidas    = @qt_linhas_lidas,
           qt_linhas_gravadas = @qt_linhas_gravadas,
           st_execucao        = @st_execucao,
           ds_observacao      = @ds_observacao
     WHERE id_log = @id_log;
END
GO
