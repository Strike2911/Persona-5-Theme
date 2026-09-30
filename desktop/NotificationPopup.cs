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
 readonly Font labelFont=new Font("Segoe UI",8.5f,FontStyle.Bold);
 readonly Font titleFont=new Font("Segoe UI",15,FontStyle.Bold);
 readonly Font bodyFont=new Font("Segoe UI",10.5f);
 readonly Font actionFont=new Font("Segoe UI",9,FontStyle.Bold);
 readonly Color red=Color.FromArgb(236,20,57);
 readonly Button open=new Button(), dismiss=new Button(), close=new Button();
 public PersonaNotice(){
  FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;
  AutoScaleMode=AutoScaleMode.None;BackColor=Color.FromArgb(18,18,22);DoubleBuffered=true;
  float scale;using(var g=CreateGraphics())scale=g.DpiX/96f;
  ClientSize=new Size((int)(420*scale),(int)(202*scale));
  Configure(open,"Abrir WhatsApp  →",new Rectangle(24,151,177,34),red,Color.White,scale);
  Configure(dismiss,"No mostrar",new Rectangle(217,151,116,34),Color.FromArgb(35,35,42),Color.FromArgb(210,210,216),scale);
  Configure(close,"×",new Rectangle(376,12,30,30),BackColor,Color.FromArgb(185,185,195),scale);
  close.Font=titleFont;close.AccessibleName="Cerrar notificación";dismiss.AccessibleDescription="Desactivar los avisos emergentes del tema";
  open.Click+=(s,e)=>{Dismiss();OpenWhatsApp();};
  close.Click+=(s,e)=>Dismiss();
  dismiss.Click+=(s,e)=>{Dismiss();if(DisableRequested!=null)DisableRequested();};
  life.Interval=6500;life.Tick+=(s,e)=>Dismiss();
  MouseEnter+=(s,e)=>life.Stop();MouseLeave+=(s,e)=>ResumeLife();
  MouseClick+=(s,e)=>{Dismiss();OpenWhatsApp();};
 }
 void Configure(Button button,string text,Rectangle rect,Color background,Color foreground,float scale){
  button.Text=text;button.Font=actionFont;button.FlatStyle=FlatStyle.Flat;button.FlatAppearance.BorderSize=0;
  button.BackColor=background;button.ForeColor=foreground;button.Cursor=Cursors.Hand;
  button.Bounds=new Rectangle((int)(rect.X*scale),(int)(rect.Y*scale),(int)(rect.Width*scale),(int)(rect.Height*scale));
  button.FlatAppearance.MouseOverBackColor=background==red?Color.FromArgb(255,43,77):Color.FromArgb(51,51,61);
  button.UseVisualStyleBackColor=false;button.MouseEnter+=(s,e)=>life.Stop();button.MouseLeave+=(s,e)=>ResumeLife();Controls.Add(button);
 }
 void ResumeLife(){if(Visible&&!ClientRectangle.Contains(PointToClient(Cursor.Position))){life.Stop();life.Start();}}
 void Dismiss(){life.Stop();Hide();}
 void OpenWhatsApp(){foreach(var p in Process.GetProcessesByName("WhatsApp.Root")){using(p){if(p.MainWindowHandle!=IntPtr.Zero){ShowWindowAsync(p.MainWindowHandle,9);SetForegroundWindow(p.MainWindowHandle);break;}}}}
 protected override bool ShowWithoutActivation {get{return true;}}
 protected override CreateParams CreateParams {get{var p=base.CreateParams;p.ExStyle|=0x08000000|0x80;return p;}}
 public void Present(string title,string text){heading=title;body=text;
  var screen=Screen.PrimaryScreen;
  foreach(var process in Process.GetProcessesByName("WhatsApp.Root")){using(process){if(process.MainWindowHandle!=IntPtr.Zero){screen=Screen.FromHandle(process.MainWindowHandle);break;}}}
  var bounds=screen.WorkingArea;Location=new Point(bounds.Right-Width-16,bounds.Bottom-Height-16);
  Invalidate();Show();life.Stop();life.Start();}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);var g=e.Graphics;
  g.ScaleTransform(ClientSize.Width/420f,ClientSize.Height/202f);g.SmoothingMode=SmoothingMode.AntiAlias;
  g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
  using(var edge=new Pen(Color.FromArgb(62,62,70)))g.DrawRectangle(edge,.5f,.5f,419,201);
  using(var accent=new SolidBrush(red)){
   g.FillRectangle(accent,0,0,4,202);
   g.FillPolygon(accent,new[]{new Point(24,17),new Point(55,17),new Point(50,37),new Point(19,37)});
  }
  using(var tag=new Font("Segoe UI",9,FontStyle.Bold))g.DrawString("P5",tag,Brushes.White,26,19);
  using(var muted=new SolidBrush(Color.FromArgb(164,164,178)))g.DrawString("NUEVO MENSAJE",labelFont,muted,65,20);
  using(var format=new StringFormat{Trimming=StringTrimming.EllipsisCharacter,FormatFlags=StringFormatFlags.NoWrap})
   g.DrawString(heading,titleFont,Brushes.White,new RectangleF(24,49,366,30),format);
  using(var format=new StringFormat{Trimming=StringTrimming.EllipsisCharacter,FormatFlags=StringFormatFlags.LineLimit})
  using(var text=new SolidBrush(Color.FromArgb(207,207,216)))
   g.DrawString(body,bodyFont,text,new RectangleF(24,88,367,46),format);
  using(var line=new Pen(Color.FromArgb(44,44,53)))g.DrawLine(line,24,140,396,140);
 }
 protected override void Dispose(bool disposing){if(disposing){life.Dispose();labelFont.Dispose();titleFont.Dispose();bodyFont.Dispose();actionFont.Dispose();}base.Dispose(disposing);}
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
