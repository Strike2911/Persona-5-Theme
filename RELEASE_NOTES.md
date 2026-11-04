## 1.3.11

- Corregido el arranque tras iniciar Windows cuando WhatsApp todavia esta creando su pagina o reemplaza la ventana de WebView2.
- Si el puerto local desaparece justo despues de aplicar el tema, el lanzador recupera la sesion una vez antes de abrir WhatsApp normal.
- El cierre espera la salida real del proceso anterior y los arranques simultaneos no se duplican durante la espera de inicio.
- Se mantiene la comprobacion de que la depuracion este limitada al equipo. No se borran chats, sesiones ni preferencias.
