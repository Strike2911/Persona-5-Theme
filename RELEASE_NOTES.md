## 1.3.8

- Corrige el fallo Clase no valida despues de aplicar el tema cuando falla la consulta CIM de conexiones TCP.
- Comprueba los puertos reales IPv4 e IPv6 mediante .NET, sin depender de Get-NetTCPConnection. Mantiene el rechazo de puertos abiertos a la red y de puertos ausentes.
- El registro de arranque identifica la etapa, tipo de error y linea para distinguir fallos de red, activacion y permisos.
- No modifica WMI, permisos de Windows ni protecciones del antivirus.
- Corrige la desinstalacion iniciada desde un acceso directo que mantiene bloqueada la carpeta desktop: libera el directorio de trabajo nativo y espera brevemente a que Windows libere los archivos.
- El cierre de los componentes propios al desinstalar ya no depende de CIM. Si falla, guarda uninstall-error.log fuera del programa.
