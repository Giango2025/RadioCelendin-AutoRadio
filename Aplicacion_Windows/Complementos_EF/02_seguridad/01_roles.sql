USE RadioCelendinAutoRadio;
GO
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name='rol_autoradio_admin') CREATE ROLE rol_autoradio_admin;
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name='rol_autoradio_operador') CREATE ROLE rol_autoradio_operador;
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name='rol_autoradio_auditor') CREATE ROLE rol_autoradio_auditor;
GO
GRANT CONTROL ON SCHEMA::dbo TO rol_autoradio_admin;
GRANT SELECT ON dbo.Audio TO rol_autoradio_operador;
GRANT SELECT ON dbo.Bloque TO rol_autoradio_operador;
GRANT SELECT ON dbo.SpotProgramado TO rol_autoradio_operador;
GRANT SELECT ON dbo.Campana TO rol_autoradio_operador;
GRANT EXECUTE ON dbo.usp_ProgramarSpot TO rol_autoradio_operador;
DENY INSERT,UPDATE,DELETE ON dbo.Auditoria TO rol_autoradio_operador;
GRANT SELECT ON dbo.Auditoria TO rol_autoradio_auditor;
DENY INSERT,UPDATE,DELETE ON dbo.Auditoria TO rol_autoradio_auditor;
GO
-- Usuarios de demostración SIN LOGIN. No usar para acceso productivo.
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name='usuario_demo_operador') CREATE USER usuario_demo_operador WITHOUT LOGIN;
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name='usuario_demo_auditor') CREATE USER usuario_demo_auditor WITHOUT LOGIN;
GO
ALTER ROLE rol_autoradio_operador ADD MEMBER usuario_demo_operador;
ALTER ROLE rol_autoradio_auditor ADD MEMBER usuario_demo_auditor;
GO
-- Ejecutar como dueño de BD para inspeccionar privilegios:
SELECT role_p.name AS rol,member_p.name AS usuario
FROM sys.database_role_members rm
JOIN sys.database_principals role_p ON rm.role_principal_id=role_p.principal_id
JOIN sys.database_principals member_p ON rm.member_principal_id=member_p.principal_id
WHERE role_p.name LIKE 'rol_autoradio_%';
GO
