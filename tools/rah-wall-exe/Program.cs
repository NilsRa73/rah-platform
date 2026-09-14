using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Windows.Forms;

namespace RahWall
{
    internal enum WallMode { Dashboard, Clock, Pulse, Auto }

    internal static class Program
    {
        [STAThread]
        private static int Main(string[] args)
        {
            if (args.Any(a => string.Equals(a, "--self-test", StringComparison.OrdinalIgnoreCase)))
            {
                // Headless build validation path used by CI.
                var names = Enum.GetNames(typeof(WallMode));
                return names.Length == 4 && names.Contains("Dashboard") && names.Contains("Clock") && names.Contains("Pulse") && names.Contains("Auto") ? 0 : 2;
            }

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            WallMode mode = ParseMode(args);
            int screenIndex = ParseScreen(args);
            Application.Run(new WallForm(mode, screenIndex));
            return 0;
        }

        private static WallMode ParseMode(string[] args)
        {
            for (int i = 0; i < args.Length; i++)
            {
                if ((args[i] == "--mode" || args[i] == "-m") && i + 1 < args.Length)
                {
                    WallMode parsed;
                    if (Enum.TryParse(args[i + 1], true, out parsed)) return parsed;
                }
                if (args[i].StartsWith("--mode=", StringComparison.OrdinalIgnoreCase))
                {
                    WallMode parsed;
                    if (Enum.TryParse(args[i].Substring(7), true, out parsed)) return parsed;
                }
            }
            return WallMode.Dashboard;
        }

        private static int ParseScreen(string[] args)
        {
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--screen" && i + 1 < args.Length)
                {
                    int n;
                    if (int.TryParse(args[i + 1], out n)) return n;
                }
                if (args[i].StartsWith("--screen=", StringComparison.OrdinalIgnoreCase))
                {
                    int n;
                    if (int.TryParse(args[i].Substring(9), out n)) return n;
                }
            }
            return -1;
        }
    }

    internal sealed class WallForm : Form
    {
        private readonly Timer timer;
        private readonly Font titleFont;
        private readonly Font labelFont;
        private readonly Font valueFont;
        private readonly Font clockFont;
        private readonly Font pulseFont;
        private readonly Font hintFont;
        private readonly Brush gold;
        private readonly Brush goldBright;
        private readonly Brush white;
        private readonly Brush muted;
        private readonly Brush green;
        private readonly Pen goldPen;
        private WallMode mode;
        private WallMode activeScene;
        private DateTime lastAutoSwitch;
        private bool blackout;
        private double phase;
        private Rectangle bounds;

        public WallForm(WallMode initialMode, int requestedScreen)
        {
            mode = initialMode;
            activeScene = initialMode == WallMode.Auto ? WallMode.Dashboard : initialMode;
            lastAutoSwitch = DateTime.Now;

            var screens = Screen.AllScreens;
            Screen target = null;
            if (requestedScreen >= 0 && requestedScreen < screens.Length) target = screens[requestedScreen];
            if (target == null) target = screens.FirstOrDefault(s => !s.Primary) ?? Screen.PrimaryScreen;
            bounds = target.Bounds;

            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            Bounds = bounds;
            BackColor = Color.FromArgb(6, 6, 8);
            ForeColor = Color.Gainsboro;
            TopMost = true;
            ShowInTaskbar = true;
            KeyPreview = true;
            DoubleBuffered = true;
            Text = "RAH WALL";

            titleFont = new Font("Segoe UI", ScaleFont(34f), FontStyle.Bold, GraphicsUnit.Point);
            labelFont = new Font("Consolas", ScaleFont(13f), FontStyle.Bold, GraphicsUnit.Point);
            valueFont = new Font("Consolas", ScaleFont(24f), FontStyle.Bold, GraphicsUnit.Point);
            clockFont = new Font("Consolas", ScaleFont(78f), FontStyle.Bold, GraphicsUnit.Point);
            pulseFont = new Font("Segoe UI", ScaleFont(58f), FontStyle.Bold, GraphicsUnit.Point);
            hintFont = new Font("Segoe UI", ScaleFont(10f), FontStyle.Regular, GraphicsUnit.Point);

            gold = new SolidBrush(Color.FromArgb(212, 175, 55));
            goldBright = new SolidBrush(Color.FromArgb(255, 220, 115));
            white = new SolidBrush(Color.Gainsboro);
            muted = new SolidBrush(Color.FromArgb(125, 126, 134));
            green = new SolidBrush(Color.FromArgb(90, 225, 130));
            goldPen = new Pen(Color.FromArgb(145, 212, 175, 55), Math.Max(1f, ScaleFont(1.7f)));

            timer = new Timer();
            timer.Interval = 33;
            timer.Tick += delegate
            {
                phase += 0.06;
                if (mode == WallMode.Auto && (DateTime.Now - lastAutoSwitch).TotalSeconds >= 8)
                {
                    CycleScene();
                    lastAutoSwitch = DateTime.Now;
                }
                Invalidate();
            };
            timer.Start();

            KeyDown += OnKeyDown;
            MouseClick += delegate(object s, MouseEventArgs e)
            {
                if (e.Button == MouseButtons.Left) CycleScene();
                if (e.Button == MouseButtons.Right) ShowSceneMenu(e.Location);
            };
        }

        private float ScaleFont(float baseSize)
        {
            float factor = Math.Max(0.72f, Math.Min(1.45f, bounds.Width / 1920f));
            return baseSize * factor;
        }

        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape) Close();
            else if (e.KeyCode == Keys.Space) { CycleScene(); e.Handled = true; }
            else if (e.KeyCode == Keys.B) { blackout = !blackout; Invalidate(); }
            else if (e.KeyCode == Keys.D) SetMode(WallMode.Dashboard);
            else if (e.KeyCode == Keys.C) SetMode(WallMode.Clock);
            else if (e.KeyCode == Keys.P) SetMode(WallMode.Pulse);
            else if (e.KeyCode == Keys.A) SetMode(WallMode.Auto);
            else if (e.KeyCode == Keys.F11) ToggleBorder();
        }

        private void ToggleBorder()
        {
            FormBorderStyle = FormBorderStyle == FormBorderStyle.None ? FormBorderStyle.Sizable : FormBorderStyle.None;
        }

        private void SetMode(WallMode newMode)
        {
            mode = newMode;
            activeScene = newMode == WallMode.Auto ? WallMode.Dashboard : newMode;
            lastAutoSwitch = DateTime.Now;
            blackout = false;
            Invalidate();
        }

        private void CycleScene()
        {
            blackout = false;
            if (activeScene == WallMode.Dashboard) activeScene = WallMode.Clock;
            else if (activeScene == WallMode.Clock) activeScene = WallMode.Pulse;
            else activeScene = WallMode.Dashboard;
            if (mode != WallMode.Auto) mode = activeScene;
            lastAutoSwitch = DateTime.Now;
            Invalidate();
        }

        private void ShowSceneMenu(Point location)
        {
            var menu = new ContextMenuStrip();
            menu.Items.Add("Dashboard", null, delegate { SetMode(WallMode.Dashboard); });
            menu.Items.Add("Big Clock", null, delegate { SetMode(WallMode.Clock); });
            menu.Items.Add("Raven Pulse", null, delegate { SetMode(WallMode.Pulse); });
            menu.Items.Add("Auto Cycle", null, delegate { SetMode(WallMode.Auto); });
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add("Blackout", null, delegate { blackout = !blackout; Invalidate(); });
            menu.Items.Add("Exit", null, delegate { Close(); });
            menu.Show(this, location);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            var g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

            if (blackout)
            {
                g.Clear(Color.Black);
                DrawFooter(g, "BLACKOUT · B TO RETURN · ESC TO EXIT", false);
                return;
            }

            DrawBackground(g);
            if (activeScene == WallMode.Dashboard) DrawDashboard(g);
            else if (activeScene == WallMode.Clock) DrawClock(g);
            else DrawPulse(g);
            DrawFooter(g, "SPACE/CLICK NEXT · D DASHBOARD · C CLOCK · P PULSE · A AUTO · B BLACKOUT · ESC EXIT", true);
        }

        private void DrawBackground(Graphics g)
        {
            g.Clear(Color.FromArgb(6, 6, 8));
            using (var path = new GraphicsPath())
            {
                path.AddEllipse(ClientRectangle.Width / 2 - ClientRectangle.Width / 3,
                                ClientRectangle.Height / 2 - ClientRectangle.Height / 3,
                                ClientRectangle.Width * 2 / 3,
                                ClientRectangle.Height * 2 / 3);
                using (var brush = new PathGradientBrush(path))
                {
                    brush.CenterColor = Color.FromArgb(34, 212, 175, 55);
                    brush.SurroundColors = new[] { Color.FromArgb(0, 6, 6, 8) };
                    g.FillPath(brush, path);
                }
            }

            using (var scan = new Pen(Color.FromArgb(12, 212, 175, 55), 1))
            {
                for (int y = 0; y < ClientSize.Height; y += 8) g.DrawLine(scan, 0, y, ClientSize.Width, y);
            }
        }

        private void DrawHeader(Graphics g, string subtitle)
        {
            g.DrawString("RAH RAVEN", titleFont, gold, Px(60), Py(45));
            g.DrawString(subtitle, labelFont, white, Px(64), Py(112));
            var modeText = mode == WallMode.Auto ? "AUTO CYCLE" : activeScene.ToString().ToUpperInvariant();
            var size = g.MeasureString(modeText, labelFont);
            g.DrawString(modeText, labelFont, muted, ClientSize.Width - size.Width - Px(60), Py(58));
        }

        private void DrawDashboard(Graphics g)
        {
            DrawHeader(g, "PROJECTOR NODE // NATIVE WINDOWS WALL");
            int gap = (int)Px(22);
            int left = (int)Px(70);
            int top = (int)Py(190);
            int width = ClientSize.Width - left * 2;
            int cardW = (width - gap) / 2;
            int cardH = (ClientSize.Height - top - (int)Py(150) - gap) / 2;

            DrawCard(g, new Rectangle(left, top, cardW, cardH), "PROJECTOR WALL", "ACER X133PWH");
            DrawCard(g, new Rectangle(left + cardW + gap, top, cardW, cardH), "ENGINE", "RAH-WALL.EXE");
            DrawCard(g, new Rectangle(left, top + cardH + gap, cardW, cardH), "WINDOWS NODE", Environment.MachineName);
            DrawCard(g, new Rectangle(left + cardW + gap, top + cardH + gap, cardW, cardH), "LOCAL TIME", DateTime.Now.ToString("HH:mm:ss"));
        }

        private void DrawCard(Graphics g, Rectangle rect, string label, string value)
        {
            using (var fill = new SolidBrush(Color.FromArgb(205, 18, 18, 23)))
            using (var border = new Pen(Color.FromArgb(105, 212, 175, 55), Math.Max(1f, ScaleFont(1f))))
            {
                var r = Rounded(rect, (int)Px(18));
                g.FillPath(fill, r);
                g.DrawPath(border, r);
                r.Dispose();
            }
            g.DrawString(label, labelFont, muted, rect.Left + Px(24), rect.Top + Py(20));
            var valueSize = g.MeasureString(value, valueFont);
            float x = rect.Left + (rect.Width - valueSize.Width) / 2f;
            float y = rect.Top + (rect.Height - valueSize.Height) / 2f + Py(10);
            g.DrawString(value, valueFont, goldBright, x, y);
        }

        private void DrawClock(Graphics g)
        {
            DrawHeader(g, "BIG CLOCK // PROJECTOR MODE");
            string time = DateTime.Now.ToString("HH:mm:ss");
            string date = DateTime.Now.ToString("dddd  dd MMMM yyyy");
            var ts = g.MeasureString(time, clockFont);
            g.DrawString(time, clockFont, goldBright, (ClientSize.Width - ts.Width) / 2f, ClientSize.Height * 0.34f);
            var ds = g.MeasureString(date, valueFont);
            g.DrawString(date, valueFont, white, (ClientSize.Width - ds.Width) / 2f, ClientSize.Height * 0.61f);
        }

        private void DrawPulse(Graphics g)
        {
            DrawHeader(g, "RAVEN PULSE // NATIVE GDI+ ANIMATION");
            float cx = ClientSize.Width / 2f;
            float cy = ClientSize.Height / 2f + Py(20);
            float baseR = Math.Min(ClientSize.Width, ClientSize.Height) * 0.12f;
            for (int i = 0; i < 5; i++)
            {
                float r = baseR * (1.0f + i * 0.48f + (float)(0.05 * Math.Sin(phase + i)));
                int alpha = Math.Max(28, 150 - i * 24);
                using (var pen = new Pen(Color.FromArgb(alpha, 212, 175, 55), Math.Max(1f, ScaleFont(1.5f))))
                    g.DrawEllipse(pen, cx - r, cy - r, r * 2, r * 2);
            }

            string rune = "R";
            var rs = g.MeasureString(rune, pulseFont);
            float pulse = 1f + (float)(0.08 * Math.Sin(phase));
            using (var dynamicFont = new Font(pulseFont.FontFamily, pulseFont.Size * pulse, FontStyle.Bold))
            {
                var ds = g.MeasureString(rune, dynamicFont);
                g.DrawString(rune, dynamicFont, goldBright, cx - ds.Width / 2f, cy - ds.Height / 2f - Py(20));
            }
            string text = "RAVEN PULSE";
            var txt = g.MeasureString(text, valueFont);
            g.DrawString(text, valueFont, gold, cx - txt.Width / 2f, cy + baseR * 1.6f);
        }

        private void DrawFooter(Graphics g, string text, bool online)
        {
            g.DrawString(text, hintFont, muted, Px(55), ClientSize.Height - Py(58));
            string right = online ? "RAH WALL ONLINE" : "BLACKOUT";
            var size = g.MeasureString(right, labelFont);
            g.DrawString(right, labelFont, online ? green : muted, ClientSize.Width - size.Width - Px(55), ClientSize.Height - Py(60));
        }

        private float Px(float x) { return x * ClientSize.Width / 1920f; }
        private float Py(float y) { return y * ClientSize.Height / 1080f; }

        private static GraphicsPath Rounded(Rectangle rect, int radius)
        {
            int d = Math.Max(2, radius * 2);
            var p = new GraphicsPath();
            p.AddArc(rect.Left, rect.Top, d, d, 180, 90);
            p.AddArc(rect.Right - d, rect.Top, d, d, 270, 90);
            p.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            p.AddArc(rect.Left, rect.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                timer.Dispose();
                titleFont.Dispose(); labelFont.Dispose(); valueFont.Dispose(); clockFont.Dispose(); pulseFont.Dispose(); hintFont.Dispose();
                gold.Dispose(); goldBright.Dispose(); white.Dispose(); muted.Dispose(); green.Dispose(); goldPen.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
