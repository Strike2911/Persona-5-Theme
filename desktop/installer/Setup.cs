using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

static class Bundle {
 public static string Destination = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\WhatsAppPersona5\desktop");
 public static string PendingReport = "";
 public static void Run(bool verify, bool autoStart = true, bool update = false) {
  PendingReport="";
  string temp = Path.Combine(Path.GetTempPath(), "WhatsAppPersona5-" + Guid.NewGuid().ToString("N"));
  Directory.CreateDirectory(temp);
  try {
   string zip = Path.Combine(temp,"package.zip");
   using(var source=Assembly.GetExecutingAssembly().GetManifestResourceStream("package.zip"))
   using(var output=File.Create(zip)) { if(source==null)throw new Exception("El instalador está incompleto. Descárgalo de nuevo."); source.CopyTo(output); }
   string unpack=Path.Combine(temp,"unpack");
   ZipFile.ExtractToDirectory(zip,unpack);
   var psi = new ProcessStartInfo(PowerShell(), "-NoProfile -ExecutionPolicy Bypass -File \""+Path.Combine(unpack,"Install.ps1")+"\" "+(verify?"-CheckOnly":"-Silent -StartupMode "+(update?"Keep":(autoStart?"Enable":"Disable"))));
   psi.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\Modules"); psi.UseShellExecute=false; psi.CreateNoWindow=true; psi.RedirectStandardError=true; psi.RedirectStandardOutput=true;
   using(var p=Process.Start(psi)) {
    var stdout=p.StandardOutput.ReadToEndAsync(); var stderr=p.StandardError.ReadToEndAsync();
    p.WaitForExit(); System.Threading.Tasks.Task.WaitAll(stdout,stderr);
    if(p.ExitCode!=0) {
     string detail=stderr.Result.Length>0?stderr.Result:stdout.Result;
     string reportPath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "WhatsAppPersona5", "install-error.log");
     string saved="";
     try { Directory.CreateDirectory(Path.GetDirectoryName(reportPath)); File.WriteAllText(reportPath, "Fecha: "+DateTimeOffset.Now.ToString("o")+Environment.NewLine+"Salida: "+p.ExitCode+Environment.NewLine+detail+Environment.NewLine+stdout.Result); saved="\n\nInforme guardado en:\n"+reportPath; } catch { }
     if(p.ExitCode==2 && !verify) { PendingReport=detail+saved; return; }
     throw new Exception(detail+saved);
    }
   }
  } finally { try { if(temp.StartsWith(Path.Combine(Path.GetTempPath(),"WhatsAppPersona5-"),StringComparison.OrdinalIgnoreCase))Directory.Delete(temp,true); } catch {} }
 }
 public static string PowerShell() { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"); }
 public static void Launch() {
  var psi=new ProcessStartInfo(PowerShell(),"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \""+Path.Combine(Destination,"Start-WhatsApp.ps1")+"\"") {UseShellExecute=false,CreateNoWindow=true}; psi.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\Modules"); Process.Start(psi);
 }
}
class Installer : Form {
 readonly Color red=Color.FromArgb(224,5,37);
 Panel content; Label step; Button next,back; CheckBox consent, startupChoice; bool autoStart=true; ProgressBar progress; int page=0; bool busy=false;
 public Installer() {
  Text="WhatsApp Persona 5 · Instalador"; ClientSize=new Size(740,540); MinimumSize=Size; MaximumSize=Size;
  Icon=System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);
  StartPosition=FormStartPosition.CenterScreen; FormBorderStyle=FormBorderStyle.FixedSingle; MaximizeBox=false;
  AutoScaleMode=AutoScaleMode.Dpi; Font=new Font("Segoe UI",10); BackColor=Color.FromArgb(15,15,18); ForeColor=Color.White;
  var banner=new Panel {Dock=DockStyle.Top,Height=98,BackColor=red}; Controls.Add(banner);
  banner.Controls.Add(new Label {Text="WHATSAPP / PERSONA 5",Font=new Font("Segoe UI",23,FontStyle.Bold),AutoSize=true,Location=new Point(26,12)});
  step=new Label {AutoSize=true,Location=new Point(29,64)};banner.Controls.Add(step);
  content=new Panel {Location=new Point(28,116),Size=new Size(684,340)};Controls.Add(content);
  next=new Button {Text="Comenzar",Location=new Point(504,474),Size=new Size(206,42),FlatStyle=FlatStyle.Flat,BackColor=red,ForeColor=Color.White};
  next.FlatAppearance.BorderSize=0;next.Click+=Next; Controls.Add(next);
  back=new Button {Text="Salir",Location=new Point(28,474),Size=new Size(125,42),FlatStyle=FlatStyle.Flat,ForeColor=Color.White};
  back.Click+=(s,e)=>{if(page==1){page=0;Render();}else Close();};Controls.Add(back);
  FormClosing+=(s,e)=>{if(busy)e.Cancel=true;}; Render();
 }
 void Label(string text,int y,int height,float size,bool bold) {
  content.Controls.Add(new Label {Text=text,Location=new Point(0,y),Size=new Size(675,height),Font=new Font("Segoe UI",size,bold?FontStyle.Bold:FontStyle.Regular)});
 }
 void Render() {
  content.Controls.Clear(); next.Enabled=true; back.Enabled=true;
  if(page==0) {
   step.Text="1 / 3   BIENVENIDA";next.Text="Comenzar";back.Text="Salir";
   Label("Tu WhatsApp, con estilo Persona 5.",0,44,21,true);
   Label("Instala el tema en unos pasos. No necesitas escribir comandos,\nelegir carpetas ni instalar programas adicionales.",60,64,12,false);
   Label("Antes de empezar",145,32,13,true);
   Label("• Necesitas Windows de 64 bits.\n• Ten WhatsApp oficial instalado desde Microsoft Store.\n• Los accesos se crean en Inicio y, si es posible, en el escritorio.\n• Tus conversaciones y tu cuenta permanecen en WhatsApp.",186,130,11,false);
  } else if(page==1) {
   step.Text="2 / 3   ANTES DE INSTALAR";next.Text="Instalar tema";back.Text="Atrás";next.Enabled=false;
   Label("Una cosa que debes saber",0,40,20,true);
   Label("El tema abre WhatsApp con una conexión de depuración local.\nPermite cambiar su aspecto, pero otros programas de tu PC\npodrían acceder a esa ventana mientras esté abierta.",55,85,12,false);
   Label("Para quitar el tema, usa «WhatsApp Persona 5 - Desinstalar».\nCerrar solo la ventana puede dejar WhatsApp en la bandeja.\nEl tema descarga e instala actualizaciones al abrirlo.",151,80,11,false);
   consent=new CheckBox {Text="Entiendo y quiero instalar el tema en este equipo.",Location=new Point(0,235),Size=new Size(675,30),ForeColor=Color.White};
   consent.CheckedChanged+=(s,e)=>next.Enabled=consent.Checked;content.Controls.Add(consent);
   startupChoice=new CheckBox {Text="Abrir WhatsApp con Persona 5 al iniciar Windows",Checked=autoStart,Location=new Point(0,272),Size=new Size(675,30),ForeColor=Color.White}; startupChoice.CheckedChanged+=(s,e)=>autoStart=startupChoice.Checked;content.Controls.Add(startupChoice);
   Label("Proyecto no oficial. No requiere permisos de administrador.",310,28,9,false);
  } else if(page==2) {
   step.Text="3 / 3   INSTALANDO";next.Text="Instalando…";next.Enabled=false;back.Enabled=false;
   Label("Estamos preparando todo",0,44,21,true);
   Label("Verificando archivos, copiando el tema y creando los accesos.\nEspera un momento; esta ventana terminará automáticamente.",66,70,12,false);
   progress=new ProgressBar {Location=new Point(0,167),Size=new Size(672,20),Style=ProgressBarStyle.Marquee};content.Controls.Add(progress);
  } else if(page==4) {
   step.Text="ARCHIVOS COPIADOS · CONFIGURACIÓN PENDIENTE";next.Text="Terminar";back.Visible=false;
   Label("La configuración quedó incompleta",0,46,21,true);
   var report=new TextBox {Multiline=true,ReadOnly=true,ScrollBars=ScrollBars.Vertical,Text=Bundle.PendingReport,Location=new Point(0,60),Size=new Size(675,260),BackColor=BackColor,ForeColor=ForeColor};content.Controls.Add(report);
  } else {
   step.Text="LISTO PARA USAR";next.Text="Abrir WhatsApp";back.Text="Terminar";
   Label("¡Ya está instalado!",0,46,24,true);
   Label("Busca estos accesos en el menú Inicio:",68,32,12,false);
   Label("WhatsApp Persona 5\nAbre WhatsApp con el tema completo.\n\nWhatsApp Persona 5 - Buscar actualizaciones\nDescarga e instala la ultima version automaticamente.\n\nWhatsApp Persona 5 - Desinstalar\nQuita el tema, sus accesos y el inicio automatico.\nConserva WhatsApp y tus conversaciones.",109,230,10,false);
  }
 }
 void Next(object sender,EventArgs e) {
  if(page==4) {Close();return;}
  if(page==0) {page=1;Render();return;}
  if(page==3) {try {Bundle.Launch();Close();}catch(Exception error){MessageBox.Show(error.Message,"No se pudo abrir WhatsApp");}return;}
  if(page!=1||!consent.Checked)return;
  busy=true;page=2;Render();var worker=new BackgroundWorker();
  worker.DoWork+=(s,a)=>Bundle.Run(false,autoStart);
  worker.RunWorkerCompleted+=(s,a)=>{
   busy=false;
   if(a.Error!=null){page=1;Render();MessageBox.Show("No se completó la instalación. El detalle siguiente indica qué paso falló.\n\nDetalle:\n"+a.Error.Message,"No se pudo instalar",MessageBoxButtons.OK,MessageBoxIcon.Information);}
   else {page=String.IsNullOrEmpty(Bundle.PendingReport)?3:4;Render();}
   worker.Dispose();
  };worker.RunWorkerAsync();
 }
}
static class Setup {
 [STAThread] static int Main(string[] args) {
  if(args.Length==1&&args[0]=="--update") {
   try {
    if(!File.Exists(Path.Combine(Bundle.Destination,"version.json")))throw new Exception("No existe una instalacion que actualizar.");
    Bundle.Run(false,true,true);
    if(!String.IsNullOrEmpty(Bundle.PendingReport))return 2;
    return 0;
   } catch(Exception e) {
    try {var dir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"WhatsAppPersona5");Directory.CreateDirectory(dir);File.WriteAllText(Path.Combine(dir,"install-error.log"),e.ToString());}catch{}
    return 1;
   }
  }
  if(args.Length==1&&args[0]=="--verify") {try{Bundle.Run(true);return 0;}catch(Exception e){File.WriteAllText(Path.Combine(Path.GetTempPath(),"WhatsAppPersona5-verify.txt"),e.ToString());return 1;}}
  Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
  Application.Run(new Installer());return 0;
 }
}





