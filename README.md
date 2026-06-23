# scripts-win

Colección de scripts funcionales para Windows — administración, herramientas UP y automatización personal.

## Estructura

```
scripts-win/
├── admin/        # Administración del sistema (usuarios, permisos, red, actualizaciones)
├── up/           # Herramientas específicas para Universidad Panamericana
├── personal/     # Automatización personal (respaldos, limpieza, productividad)
├── config/       # Configuraciones y perfiles (perfil de PowerShell, variables, etc.)
├── batch/        # Scripts .bat / .cmd
├── powershell/   # Scripts .ps1 generales o reutilizables
└── docs/         # Notas, referencias y guías de uso
```

## Scripts disponibles

### `up/install-impresionup.ps1`
Instala la cola de impresión IMPRESIONUP (Kyocera TASKalfa MZ2501ci KX) en Windows 11.

**Estructura en USB para ejecutar:**
```
IMPRESIONUP\
├── install-impresionup.ps1
└── Kyocera_64bit\          ← copiar la carpeta completa de drivers
    ├── OEMSETUP.INF
    └── (resto de archivos)
```

## Convenciones

- Scripts PowerShell: `.ps1`, nombrados en `kebab-case`
- Scripts Batch: `.bat` o `.cmd`, nombrados en `kebab-case`
- Cada script debe tener un bloque de comentario al inicio con: propósito, uso y autor
- Scripts destructivos o con privilegios deben indicarlo claramente al inicio

## Ejecución rápida (PowerShell)

```powershell
# Permitir ejecución de scripts locales
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
