using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

sealed class PersonaNotice : Form {
 public event Action DisableRequested;
 string heading="", body="";
 readonly System.Windows.Forms.Timer life=new System.Windows.Forms.Timer();
 public PersonaNotice(){FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;
  BackColor=Color.Black;DoubleBuffered=true;Size=new Size(390,172);
  life.Interval=6500;life.Tick+=(s,e)=>{life.Stop();Hide();};
  MouseClick+=(s,e)=>{Hide();life.Stop();if(e.Y>130&&e.X>Width-132){if(DisableRequested!=null)DisableRequested();return;}if(e.X<Width-44){
   foreach(var p in Process.GetProcessesByName("WhatsApp.Root")){if(p.MainWindowHandle!=IntPtr.Zero){ShowWindowAsync(p.MainWindowHandle,9);SetForegroundWindow(p.MainWindowHandle);break;}}
  }};
 }
 protected override bool ShowWithoutActivation {get{return true;}}
 protected override CreateParams CreateParams {get{var p=base.CreateParams;p.ExStyle|=0x08000000|0x80;return p;}}
 public void Present(string title,string text){heading=title;body=text;
  var screen=Screen.PrimaryScreen;
  foreach(var process in Process.GetProcessesByName("WhatsApp.Root")){if(process.MainWindowHandle!=IntPtr.Zero){screen=Screen.FromHandle(process.MainWindowHandle);break;}}
  var bounds=screen.WorkingArea;Location=new Point(bounds.Right-Width-16,bounds.Bottom-Height-16);
  Invalidate();Show();life.Stop();life.Start();}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;
  using(var red=new SolidBrush(Color.FromArgb(227,6,35)))g.FillPolygon(red,new[]{new Point(0,6),new Point(Width-8,0),new Point(Width,Height-8),new Point(9,Height)});
  g.FillPolygon(Brushes.White,new[]{new Point(8,12),new Point(Width-13,7),new Point(Width-7,Height-14),new Point(15,Height-7)});
  g.FillPolygon(Brushes.Black,new[]{new Point(13,17),new Point(Width-18,12),new Point(Width-12,Height-19),new Point(20,Height-12)});
  using(var small=new Font("Segoe UI",9,FontStyle.Bold))using(var title=new Font("Segoe UI",14,FontStyle.Bold))using(var text=new Font("Segoe UI",10)){
   g.DrawString("WHATSAPP / PERSONA 5",small,Brushes.Red,24,23);
   g.DrawString("×",title,Brushes.White,Width-39,17);
   var format=new StringFormat{Trimming=StringTrimming.EllipsisCharacter};
   g.DrawString(heading,title,Brushes.White,new RectangleF(24,44,Width-65,28),format);
   g.DrawString(body,text,Brushes.White,new RectangleF(24,79,Width-53,47),format);
   g.DrawString("ABRIR WHATSAPP   ›",small,Brushes.Yellow,24,139);
   g.DrawString("NO MOSTRAR",small,Brushes.White,Width-121,139);
  }
 }
 [DllImport("user32.dll")]static extern bool ShowWindowAsync(IntPtr h,int command);
 [DllImport("user32.dll")]static extern bool SetForegroundWindow(IntPtr h);
}

static class NotificationProgram {
 [STAThread]static void Main(string[] args){
  Application.EnableVisualStyles();
  if(args.Length==2&&args[0]=="--preview"){
   using(var sample=new PersonaNotice()){sample.Present("Aviso de prueba","Nuevo mensaje con el estilo Persona 5.");
    using(var bitmap=new Bitmap(sample.Width,sample.Height)){sample.DrawToBitmap(bitmap,new Rectangle(Point.Empty,sample.Size));bitmap.Save(args[1]);}}
   return;
  }
  var context=new ApplicationContext();var dispatch=new Control();var handle=dispatch.Handle;
  var popup=new PersonaNotice();var audio=new System.Windows.Media.MediaPlayer();
  var json=new JavaScriptSerializer();DateTime lastTone=DateTime.MinValue;
  popup.DisableRequested+=()=>{Console.WriteLine(json.Serialize(new{action="hide-banners"}));Console.Out.Flush();};
  var input=new Thread(()=>{
   string line;
   while((line=Console.ReadLine())!=null){
    if(line.Length>8192)continue;
    string captured=line;
    dispatch.BeginInvoke((Action)(()=>{
     string id="";bool ok=false;
     try{var d=json.Deserialize<Dictionary<string,object>>(captured);id=Convert.ToString(d["id"]);
      string kind=Convert.ToString(d["kind"]);
      if(kind=="notice"){popup.Present(Convert.ToString(d["title"]),Convert.ToString(d["body"]));ok=true;}
      if(kind=="tone"){
       if((DateTime.UtcNow-lastTone).TotalMilliseconds>300){
        audio.Stop();audio.Volume=Math.Max(0,Math.Min(1,Convert.ToDouble(d["volume"])));
        audio.Open(new Uri(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"assets","message-other.mp3")));audio.Play();lastTone=DateTime.UtcNow;
       }ok=true;
      }
     }catch{}
     Console.WriteLine(json.Serialize(new{id=id,ok=ok}));Console.Out.Flush();
    }));
   }
   dispatch.BeginInvoke((Action)(()=>{audio.Close();popup.Dispose();context.ExitThread();}));
  });input.IsBackground=true;input.Start();Application.Run(context);dispatch.Dispose();
 }
}
