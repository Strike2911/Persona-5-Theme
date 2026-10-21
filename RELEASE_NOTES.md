## 1.3.9

- Si WhatsApp no responde a la conexion local durante el arranque, el tema reinicia WhatsApp una sola vez y vuelve a intentar conectarse. Si falla otra vez, intenta restaurar WhatsApp normal.
- Los errores de conexion muestran su causa tecnica en el registro; ya no se interrumpe la recuperacion por un mensaje enviado a stderr.
- El aviso de error libera el bloqueo del lanzador para permitir otro intento sin tener que cerrar antes el aviso.
- Se mantiene la verificacion del puerto local y la actualizacion directa: Buscar actualizaciones descarga, verifica e instala sin abrir GitHub.
