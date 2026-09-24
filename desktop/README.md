# Persona 5 para WhatsApp oficial de Windows

Aplica el tema a **la aplicación oficial instalada desde Microsoft Store**, usando su WebView2. No instala otro cliente, no copia sesiones y no modifica WindowsApps. Probado con WhatsApp 2.2635.100.0 y WebView2 153 en este equipo.

## Abrir

Los accesos del escritorio ejecutan `Start-WhatsApp.ps1`:

- **WhatsApp Persona 5**: rediseño inspirado en el menú del teléfono de Persona 5, con entrada de mensajes de 360 ms y selección de 140 ms.
- **WhatsApp Persona 5 - Ligero**: el mismo tema sin esas transiciones.
- **WhatsApp - Restaurar normal**: reinicia la aplicación sin tema ni depuración.

Cada acceso reinicia WhatsApp: úsalo al terminar llamadas y de enviar archivos. No borra chats, ajustes ni credenciales. Requiere Windows PowerShell y Node.js 22 o posterior; en este equipo se utilizó Node.js 24.17.0. Conserva esta carpeta en su ubicación. Si la mueves, ejecuta `Install-Shortcuts.ps1` para actualizar los accesos.

La barra de título nativa de Windows conserva su aspecto. El tema afecta al contenido web. Actualizaciones de WhatsApp pueden cambiar sus selectores y requerir adaptar `persona.css` (base) y `persona-v2.css` (composición del teléfono).

### Revisión visual 2

Fondo gris carbón y negro, acentos rojos discretos, bandas angulares, nombres blancos delineados y retratos monocromos con marcos inclinados y acentos amarillos/rosas. Mensajes recibidos negros con borde blanco y enviados blancos con borde negro, sin recortar archivos ni texto. La portada incorpora “TAKE YOUR HEART”. Se mantienen las fotos reales de los contactos; no se sustituyen por personajes.

La revisión del 16 de septiembre sustituye las superficies rojas por carbón y mejora la animación: entrada lateral según el sentido del mensaje, inclinación, expansión y un rebote breve que termina en 360 ms. La caja de escritura señala el foco con un borde superior rojo, sin el rectángulo rosado sobre el texto. Las animaciones son interpretaciones de las referencias estáticas, no una copia cuadro a cuadro del juego.

### Composición de cómic

La última referencia se adapta en `comic.css`: fondo ilustrado de ciudad y Joker en negro y granate, tarjetas completas con contornos irregulares, selección roja, marcos rojos con interior negro, rótulo WhatsApp con trama y “TAKE YOUR TIME”. Se conserva la animación de mensajes de 360 ms, así como las fotografías reales de los contactos y los controles originales de llamadas, búsqueda, adjuntos y envío. La barra de título pertenece a Windows y mantiene su aspecto nativo.

El fondo actual es la ciudad monocroma proporcionada por el usuario, guardada como `assets/city-mono.jpg` (2560 × 1440, aproximadamente 491 KB). Se incrusta localmente, sin servidor ni peticiones externas para el tema. La ilustración anterior se conserva en los archivos `city-joker`. El fondo es estático. Se conserva la posición absoluta de la lista virtual de mensajes para evitar desplazar la cabecera y el campo de escritura.

Los marcos de los mensajes usan inclinaciones de pocos píxeles para que no crucen el texto de las fotos altas. Las fotos y vídeos tienen un marco casi rectangular que incluye el pie y la hora. La trama del logo cubre la cabecera y los filtros y contactos recientes de búsqueda comparten los bordes y colores del tema; se conservan sus controles originales.

## Cómo funciona y cómo desactivarlo

### Ajustes de distribución y marcos

El buscador reserva su altura y deja espacio antes de los filtros. Los nombres tienen mayor altura de línea para evitar recortar mayúsculas y acentos; los nombres largos conservan puntos suspensivos. El logo superior, la ciudad del lateral y la franja inferior son SVG locales. La barra de escritura reserva una columna para el rótulo CHAT, manteniendo los controles originales y el micrófono cuando el campo está vacío. Se corrigió la prioridad del estilo base que ocultaba el fondo del lateral. Las animaciones de mensajes se conservan.

## Activación y restauración

El lanzador activa el paquete oficial mediante `IApplicationActivationManager` y pasa `--edge-webview-switches` con un puerto aleatorio de depuración limitado a `127.0.0.1`. Inserta únicamente el CSS y una función que lo repone al recargar el documento. El ayudante termina después de aplicarlo; no mantiene un proceso vigilando chats.

**La depuración permanece disponible para otros programas locales hasta que WhatsApp termina completamente.** Cerrar solo la ventana puede dejar la aplicación en la bandeja. Usa **Restaurar normal** para terminar esa sesión y abrir una sin depuración. Abrir el icono habitual mientras ya está ejecutándose reutiliza el proceso existente y no la desactiva.

Este mecanismo fue autorizado explícitamente para este equipo. No abre el puerto a la red ni modifica políticas, variables de entorno persistentes, antivirus, certificados o archivos firmados. Un fallo al aplicar el tema provoca el reinicio normal de la app. Una ventana web nueva creada posteriormente por la aplicación puede necesitar reabrir con el acceso del tema.

Referencias técnicas: [depuración WebView2](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/debug-visual-studio-code) y [activación de aplicaciones de Windows](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-iapplicationactivationmanager-activateapplication).

## Rendimiento

La versión de escritorio usa CSS y los SVG locales del proyecto. No ejecuta los observadores ni las conexiones SVG entre mensajes de la extensión. Observa la cabecera y los hijos directos de sus contenedores para limpiar el retrato cuando cambia el contacto; no observa el subárbol de mensajes. Si la cabecera no tiene foto, no dibuja un retrato junto a los mensajes. No altera las alturas de las filas de la lista virtual, no añade bucles de animación, desenfoques ni servicios en segundo plano. Respeta la preferencia de Windows de reducir movimiento. Las entradas de mensajes pueden repetirse cuando WhatsApp vuelve a montar filas al desplazarse.

En la extensión original también se corrigieron la carga duplicada de imágenes, una referencia a un SVG inexistente y las notificaciones del observador causadas por su propio dibujo. Esas correcciones no implican que la extensión fuese la causa de las trabas de la app oficial.

Medición inicial, antes del tema: 9 procesos, suma de memoria residente 1237 MB, memoria privada 1185 MB, CPU del equipo 0,04 % durante cinco segundos. El sistema tenía aproximadamente 5 GB libres de 32 GB. Es una muestra en reposo, no un diagnóstico de la causa ni una demostración de mejora. No se ha desactivado la GPU ni vaciado cachés a ciegas.

Para tomar otra muestra sin leer mensajes:

```powershell
.\Diagnose-WhatsApp.ps1 -Seconds 10
```

Para comprobar la construcción y aislamiento del tema:

```powershell
node --test .\theme.test.mjs
```

No se garantiza eliminar bloqueos internos de WhatsApp, WebView2 o del controlador gráfico. El modo Ligero reduce el coste de este tema, no el consumo completo de WhatsApp.

## Licencia

Se conservan los recursos y la licencia GPL-3.0 del proyecto original. Adaptación no oficial, sin afiliación con Meta, Atlus o Sega.


### Contraste y modo claro (1.2.1)

`contrast.css` fija la paleta sobre `body` y `#app`, donde WhatsApp define los colores del modo claro/oscuro. Mantiene el aspecto Persona 5 sin modificar la preferencia guardada de WhatsApp. Las citas tienen un fondo opaco y colores propios; el control de opciones no pinta una franja sobre la burbuja.

Comprobación de regresión en una sesión local de desarrollo: `node desktop/dev/verify-contrast.mjs PUERTO`. El chequeo usa elementos temporales fuera de pantalla y compara los colores en ambas clases de tema; restaura el estado original en un bloque `finally`. No escribe ni envía mensajes.

### Inicio automático (1.2.2)

El instalador permite marcar **Abrir WhatsApp con Persona 5 al iniciar Windows**. Crea únicamente un acceso `WhatsApp Persona 5.lnk` en la carpeta Inicio del usuario, apuntando al lanzador con `-Startup`. Espera ocho segundos antes de activar WhatsApp para dar tiempo a la restauración de apps de Windows. No añade servicios ni vigila procesos continuamente.

Para desactivarlo, desmarca esa opción al volver a ejecutar el instalador, deshabilita la entrada de inicio en Windows o ejecuta `desktop/Set-Startup.ps1 -Disable`. «Restaurar normal» desactiva la sesión actual de depuración; si el inicio automático sigue activo, volverá a aplicar el tema en el próximo inicio de sesión de Windows.

Los accesos originales de WhatsApp no se interceptan. Si el proceso está cerrado y se abre el icono oficial, puede iniciar sin tema. Usa el acceso Persona 5 para abrirlo manualmente. Durante la carga puede verse brevemente el aspecto original.
