# Persona 5 Theme para WhatsApp

## Descargar para Windows

**[Descargar el instalador](https://github.com/Strike2911/Persona-5-Theme/releases/latest/download/WhatsApp-Persona5-Instalar.exe)** · [Ver novedades](https://github.com/Strike2911/Persona-5-Theme/releases/latest)

Abre el archivo descargado y sigue el menú. Requiere **Windows de 64 bits** y **WhatsApp oficial de Microsoft Store**. No hace falta instalar Node.js, extraer carpetas ni ejecutar comandos. El instalador de este proyecto personal no está firmado digitalmente.

El acceso del tema reinicia WhatsApp con depuración limitada a este equipo. Otros programas locales pueden acceder a esa ventana mientras la sesión está activa. Para desactivarla, usa **WhatsApp - Restaurar normal**; cerrar solo la ventana puede dejar el proceso en la bandeja. No modifica los archivos firmados de WhatsApp ni incluye sesiones, cuentas o conversaciones.

### Actualizaciones

Desde **1.2.0**, al abrir el tema se consulta GitHub como máximo una vez al día. Si hay una versión estable nueva con instalador, aparece un aviso que permite abrir su página de descarga. También se puede usar el acceso **WhatsApp Persona 5 - Buscar actualizaciones**. No descarga ni instala ejecutables automáticamente, no funciona como servicio y no envía chats ni identificadores a GitHub (solo una solicitud normal a su API).

**Quienes descargaron 1.0 o 1.1 deben instalar 1.2.0 una vez para recibir futuros avisos.** Los usuarios que mantienen WhatsApp abierto verán la comprobación al volver a iniciarlo con el acceso del tema.

### Publicar una nueva versión (mantenedor)

1. Haz y prueba los cambios.
2. Incrementa `desktop/version.json` (por ejemplo, `1.2.0` a `1.2.1`) y actualiza `RELEASE_NOTES.md`.
3. Sube esos cambios a `main`.
4. La acción **Publicar instalador** comprueba, compila y publica el `.exe` y su SHA256 como una nueva GitHub Release. El aviso solo aparece cuando esa versión está publicada y tiene instalador.

Un commit sin cambiar el número de versión no envía avisos. No reutilices números de versiones publicadas. Si la acción falla, revisa su registro en **Actions** antes de reintentar; un borrador incompleto no se anuncia.

Para compilar localmente en Windows con Node.js oficial 24.17.0 x64 instalado:

```powershell
.\desktop\installer\Build-Installer.ps1 -NodePath (Get-Command node.exe).Source
```

El script verifica el hash del runtime, ejecuta las pruebas y genera `dist/WhatsApp-Persona5-Instalar.exe`. El código del instalador está en `desktop/installer/`; las pruebas del retrato y las actualizaciones están en `desktop/*.test.mjs`.

## Créditos y extensión original

Adaptación no oficial. Se conserva la licencia GPL-3.0 y los créditos de la extensión original. No existe afiliación con Meta, Atlus o Sega. Los archivos originales de extensión siguen disponibles en este repositorio.

---

# WhatsApp Web - Persona 5 Royal Theme

## App oficial de escritorio (Windows)

Se añadió una adaptación para la app oficial de Microsoft Store, con un lanzador reversible y modos normal/ligero. Consulta [desktop/README.md](desktop/README.md) para abrirla, restaurar el aspecto original y conocer el alcance de la depuración local y las comprobaciones de rendimiento.

🇪🇸 [Español](#español) | 🇬🇧 [English](#english)

Compatible con **Google Chrome, Microsoft Edge, Mozilla Firefox y Zen Browser**.

<a href="https://ko-fi.com/pocooriginal" target="_blank"> <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"> </a>
---

## Español

Extensión que transforma la estética de WhatsApp Web, dándole un estilo inspirado en la interfaz de chats de **Persona 5 Royal**.

### ¿Qué hace?

Modifica los estilos visuales de WhatsApp Web (colores, animaciones y elementos de la interfaz) para que se vea y se sienta como los característicos menús rojos, negros y blancos de Persona 5 Royal.

### Instalación

#### Chrome / Edge (basados en Chromium)

1. Descarga o clona este repositorio.
2. Abre `chrome://extensions` (en Edge: `edge://extensions`).
3. Activa el **Modo de desarrollador**.
4. Haz clic en **Cargar descomprimida** (Load unpacked).
5. Selecciona la carpeta del proyecto (la que contiene `manifest.json`).

#### Firefox / Zen Browser  (basados en firefox)

1. Descarga o clona este repositorio.
2. Abre `about:debugging#/runtime/this-firefox`.
3. Haz clic en **Cargar complemento temporal** (Load Temporary Add-on).
4. Selecciona el archivo `manifest.json` dentro de la carpeta del proyecto.

> ⚠️ En Firefox, las extensiones cargadas de esta forma son temporales y se eliminan al cerrar el navegador. Para una instalación permanente necesitarías firmarla a través de [addons.mozilla.org](https://addons.mozilla.org).

### Uso

1. Abre [WhatsApp Web](https://web.whatsapp.com).
2. La extensión aplicará automáticamente el tema visual de Persona 5 Royal.
3. Si no ves los cambios, recarga la pestaña.

### Donaciones

Si te gusta el proyecto y quieres apoyar su desarrollo, puedes invitarme a un café:

<a href="https://ko-fi.com/pocooriginal" target="_blank"> <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"> </a>

### Notas

Proyecto no oficial hecho por fans, sin ánimo de lucro.

No está afiliado, respaldado ni asociado oficialmente con WhatsApp/Meta, Atlus o Sega, propietarios de Persona 5 Royal.

### Licencia
Este proyecto se distribuye bajo la GNU General Public License v3.0 (GPL-3.0).

Esto significa que puedes usar, estudiar, modificar y distribuir el código, siempre que las versiones modificadas o redistribuidas se publiquen también bajo la misma licencia GPL v3.

---

## English

Extension that transforms the look and feel of WhatsApp Web, giving it a style inspired by the chat interface from **Persona 5 Royal**.

### What does it do?

Modifies WhatsApp Web's visual styles (colors, animations, and UI elements) so it looks and feels like Persona 5 Royal's signature red, black, and white menus.

### Installation

#### Chrome / Edge / Zen Browser (Chromium-based)

1. Download or clone this repository.
2. Go to `chrome://extensions` (Edge: `edge://extensions`, Zen: `zen://extensions`).
3. Enable **Developer mode**.
4. Click **Load unpacked**.
5. Select the project folder (the one containing `manifest.json`).

#### Firefox / Zen Browser (firefox-based)

1. Download or clone this repository.
2. Go to `about:debugging#/runtime/this-firefox`.
3. Click **Load Temporary Add-on**.
4. Select the `manifest.json` file inside the project folder.

> ⚠️ In Firefox, extensions loaded this way are temporary and get removed when the browser closes. For a permanent install, you'd need to sign it through [addons.mozilla.org](https://addons.mozilla.org).

### Usage

1. Open [WhatsApp Web](https://web.whatsapp.com).
2. The extension will automatically apply the Persona 5 Royal visual theme.
3. If you don't see the changes, reload the tab.

## Donations

If you enjoy the project and would like to support its development, you can buy me a coffee:

<a href="https://ko-fi.com/pocooriginal" target="_blank"> <img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi"> </a>

### Notes

This is an unofficial, non-profit fan project.

It is not affiliated with, endorsed by, or officially associated with WhatsApp/Meta, Atlus, or Sega, the owners of Persona 5 Royal.

### License
This project is licensed under the GNU General Public License v3.0 (GPL-3.0).

You are free to use, study, modify, and distribute the code, provided that modified or redistributed versions are also released under the same GPL v3 license.

