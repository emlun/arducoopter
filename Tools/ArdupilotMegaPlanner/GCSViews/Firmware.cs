﻿using System;
using System.Collections.Generic;
using System.Reflection;
using System.Windows.Forms;
using System.IO.Ports;
using System.IO;
using System.Xml;
using System.Net;
using log4net;
using ArdupilotMega.Arduino;
using ArdupilotMega.Utilities;

namespace ArdupilotMega.GCSViews
{
    partial class Firmware : MyUserControl
    {
        private static readonly ILog log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);

        protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
        {
            if (keyData == (Keys.Control | Keys.C))
            {
                var fd = new OpenFileDialog {Filter = "Firmware (*.hex)|*.hex"};
                fd.ShowDialog();
                if (File.Exists(fd.FileName))
                {
                    UploadFlash(fd.FileName, ArduinoDetect.DetectBoard(MainV2.comPortName));
                }
                return true;
            }

            if (keyData == (Keys.Control | Keys.R))
            {
                findfirmware("AR2");
                return true;
            }

            return base.ProcessCmdKey(ref msg, keyData);
        }

        List<software> softwares = new List<software>();
        bool flashing = false;

        public struct software
        {
            public string url;
            public string url2560;
            public string url2560_2;
            public string name;
            public string desc;
            public int k_format_version;
        }

        public Firmware()
        {
            InitializeComponent();

            WebRequest.DefaultWebProxy.Credentials = System.Net.CredentialCache.DefaultCredentials;

            this.pictureBoxAPM.Image = ArdupilotMega.Properties.Resources.APM_airframes_001;
            this.pictureBoxQuad.Image = ArdupilotMega.Properties.Resources.quad;
            this.pictureBoxHexa.Image = ArdupilotMega.Properties.Resources.hexa;
            this.pictureBoxTri.Image = ArdupilotMega.Properties.Resources.tri;
            this.pictureBoxY6.Image = ArdupilotMega.Properties.Resources.y6;
            this.pictureBoxHeli.Image = ArdupilotMega.Properties.Resources.APM_airframes_08;
            this.pictureBoxHilimage.Image = ArdupilotMega.Properties.Resources.hil;
            this.pictureBoxAPHil.Image = ArdupilotMega.Properties.Resources.hilplane;
            this.pictureBoxACHil.Image = ArdupilotMega.Properties.Resources.hilquad;
            this.pictureBoxACHHil.Image = ArdupilotMega.Properties.Resources.hilheli;
            this.pictureBoxOcta.Image = ArdupilotMega.Properties.Resources.octo;
            this.pictureBoxOctav.Image = ArdupilotMega.Properties.Resources.octov;

        }

        internal void Firmware_Load(object sender, EventArgs e)
        {
            log.Info("FW load");

            string url = "";
            string url2560 = "";
            string url2560_2 = "";
            string name = "";
            string desc = "";
            int k_format_version = 0;

            softwares.Clear();

            software temp = new software();

            try
            {

                using (XmlTextReader xmlreader = new XmlTextReader("http://ardupilot-mega.googlecode.com/git/Tools/ArdupilotMegaPlanner/Firmware/firmware2.xml"))
                {
                    while (xmlreader.Read())
                    {
                        xmlreader.MoveToElement();
                        switch (xmlreader.Name)
                        {
                            case "url":
                                url = xmlreader.ReadString();
                                break;
                            case "url2560":
                                url2560 = xmlreader.ReadString();
                                break;
                            case "url2560-2":
                                url2560_2 = xmlreader.ReadString();
                                break;
                            case "name":
                                name = xmlreader.ReadString();
                                break;
                            case "format_version":
                                k_format_version = int.Parse(xmlreader.ReadString());
                                break;
                            case "desc":
                                desc = xmlreader.ReadString();
                                break;
                            case "Firmware":
                                if (!url.Equals("") && !name.Equals("") && !desc.Equals("Please Update"))
                                {
                                    temp.desc = desc;
                                    temp.name = name;
                                    temp.url = url;
                                    temp.url2560 = url2560;
                                    temp.url2560_2 = url2560_2;
                                    temp.k_format_version = k_format_version;

                                    try
                                    {
                                        updateDisplayName(temp);
                                    }
                                    catch { } // just in case

                                    softwares.Add(temp);
                                }
                                url = "";
                                url2560 = "";
                                name = "";
                                desc = "";
                                k_format_version = 0;
                                temp = new software();
                                break;
                            default:
                                break;
                        }
                    }
                }


            }
            catch (Exception ex)
            {
                CustomMessageBox.Show("Failed to get Firmware List : " + ex.Message);
            }
            log.Info("FW load done");

        }

        void updateDisplayName(software temp)
        {
            if (temp.url.ToLower().Contains("firmware/AP-1".ToLower()))
            {
                pictureBoxAPM.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/APHIL-".ToLower()))
            {
                pictureBoxAPHil.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-quad-".ToLower()))
            {
                pictureBoxQuad.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-tri".ToLower()))
            {
                pictureBoxTri.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-hexa".ToLower()))
            {
                pictureBoxHexa.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-y6".ToLower()))
            {
                pictureBoxY6.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-heli-1".ToLower()))
            {
                pictureBoxHeli.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-quadhil".ToLower()))
            {
                pictureBoxACHil.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-octav-".ToLower()))
            {
                pictureBoxOctav.Text = temp.name;
            }
            else if (temp.url.ToLower().Contains("firmware/ac2-octa-".ToLower()))
            {
                pictureBoxOcta.Text = temp.name;
            }
            else
            {
                log.Info("No Home " + temp.name + " " + temp.url);
            }
        }

        void findfirmware(string findwhat)
        {
            List<software> items = new List<software>();

            // build list
            foreach (software temp in softwares)
            {
                if (temp.url.ToLower().Contains(findwhat.ToLower()))
                {
                    items.Add(temp);
                }
            }

            // none found
            if (items.Count == 0)
            {
                CustomMessageBox.Show("The requested firmware was not found.");
                return;
            }
            else if (items.Count == 1) // 1 found so accept it
            {
                DialogResult dr = CustomMessageBox.Show("Are you sure you want to upload " + items[0].name + "?", "Continue", MessageBoxButtons.YesNo);
                if (dr == System.Windows.Forms.DialogResult.Yes)
                {
                    update(items[0]);
                }
                return;
            }
            else
            {
                CustomMessageBox.Show("Something has gone wrong, to many firmware choices");
                return;
            }
        }

        private void pictureBoxAPM_Click(object sender, EventArgs e)
        {
            findfirmware("firmware/AP-1");
        }

        private void pictureBoxAPMHIL_Click(object sender, EventArgs e)
        {
            findfirmware("firmware/APHIL-");
        }

        private void pictureBoxQuad_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Quad-");
        }

        private void pictureBoxHexa_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Hexa-");
        }

        private void pictureBoxTri_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Tri-");
        }

        private void pictureBoxY6_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Y6-");
        }

        private void pictureBoxHeli_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Heli-");
        }

        private void pictureBoxQuadHil_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-QUADHIL");
        }

        private void update(software temp)
        {
            string board = "";
            MainV2.comPort.BaseStream.DtrEnable = false;
            MainV2.comPort.Close();
            System.Threading.Thread.Sleep(100);
            MainV2.giveComport = true;

            try
            {
                if (softwares.Count == 0)
                {
                    CustomMessageBox.Show("No valid options");
                    return;
                }

                lbl_status.Text = "Detecting APM Version";

                this.Refresh();

                board = ArduinoDetect.DetectBoard(MainV2.comPortName);

                if (board == "")
                {
                    CustomMessageBox.Show("Cant detect your APM version. Please check your cabling");
                    return;
                }

                int apmformat_version = -1; // fail continue

                try
                {
                    apmformat_version = ArduinoDetect.decodeApVar(MainV2.comPortName, board);
                }
                catch { }

                if (apmformat_version != -1 && apmformat_version != temp.k_format_version)
                {
                    if (DialogResult.No == CustomMessageBox.Show("Epprom changed, all your setting will be lost during the update,\nDo you wish to continue?", "Epprom format changed (" + apmformat_version + " vs " + temp.k_format_version + ")", MessageBoxButtons.YesNo))
                    {
                        CustomMessageBox.Show("Please connect and backup your config in the configuration tab.");
                        return;
                    }
                }



                log.Info("Detected a " + board);

                string baseurl = "";
                if (board == "2560")
                {
                    baseurl = temp.url2560.ToString();
                }
                else if (board == "1280")
                {
                    baseurl = temp.url.ToString();
                }
                else if (board == "2560-2")
                {
                    baseurl = temp.url2560_2.ToString();
                }
                else
                {
                    CustomMessageBox.Show("Invalid Board Type");
                    return;
                }

                log.Info("Using " + baseurl);

                // Create a request using a URL that can receive a post. 
                WebRequest request = WebRequest.Create(baseurl);
                request.Timeout = 10000;
                // Set the Method property of the request to POST.
                request.Method = "GET";
                // Get the request stream.
                Stream dataStream; //= request.GetRequestStream();
                // Get the response.
                WebResponse response = request.GetResponse();
                // Display the status.
                log.Info(((HttpWebResponse)response).StatusDescription);
                // Get the stream containing content returned by the server.
                dataStream = response.GetResponseStream();

                long bytes = response.ContentLength;
                long contlen = bytes;

                byte[] buf1 = new byte[1024];

                FileStream fs = new FileStream(Path.GetDirectoryName(Application.ExecutablePath) + Path.DirectorySeparatorChar + @"firmware.hex", FileMode.Create);

                lbl_status.Text = "Downloading from Internet";

                this.Refresh();

                dataStream.ReadTimeout = 30000;

                while (dataStream.CanRead)
                {
                    try
                    {
                        progress.Value = 50;// (int)(((float)(response.ContentLength - bytes) / (float)response.ContentLength) * 100);
                        this.progress.Refresh();
                    }
                    catch { }
                    int len = dataStream.Read(buf1, 0, 1024);
                    if (len == 0)
                        break;
                    bytes -= len;
                    fs.Write(buf1, 0, len);
                }

                fs.Close();
                dataStream.Close();
                response.Close();

                progress.Value = 100;
                this.Refresh();
                log.Info("Downloaded");
            }
            catch (Exception ex) { lbl_status.Text = "Failed download"; CustomMessageBox.Show("Failed to download new firmware : " + ex.ToString()); return; }

            UploadFlash(Path.GetDirectoryName(Application.ExecutablePath) + Path.DirectorySeparatorChar + @"firmware.hex", board);
        }

        public void UploadFlash(string filename, string board)
        {
            byte[] FLASH = new byte[1];
            StreamReader sr = null;
            try
            {
                lbl_status.Text = "Reading Hex File";
                this.Refresh();
                sr = new StreamReader(filename);
                FLASH = readIntelHEXv2(sr);
                sr.Close();
                log.InfoFormat("\n\nSize: {0}\n\n", FLASH.Length);
            }
            catch (Exception ex)
            {
                if (sr != null)
                {
                    sr.Dispose();
                } 
                lbl_status.Text = "Failed read HEX"; 
                CustomMessageBox.Show("Failed to read firmware.hex : " + ex.Message); 
                return;
            }
            ArduinoComms port = new ArduinoSTK();

            if (board == "1280")
            {
                if (FLASH.Length > 126976)
                {
                    CustomMessageBox.Show("Firmware is to big for a 1280, Please upgrade your hardware!!");
                    return;
                }
                //port = new ArduinoSTK();
                port.BaudRate = 57600;
            }
            else if (board == "2560" || board == "2560-2")
            {
                port = new ArduinoSTKv2
                           {
                               BaudRate = 115200
                           };
            }
            port.DataBits = 8;
            port.StopBits = StopBits.One;
            port.Parity = Parity.None;
            port.DtrEnable = true;

            try
            {
                port.PortName = MainV2.comPortName;

                port.Open();

                flashing = true;

                if (port.connectAP())
                {
                    log.Info("starting");
                    lbl_status.Text = "Uploading " + FLASH.Length + " bytes to APM Board: "+board;
                    progress.Value = 0;
                    this.Refresh();

                    // this is enough to make ap_var reset
                    //port.upload(new byte[256], 0, 2, 0);

                    port.Progress += port_Progress;

                    if (!port.uploadflash(FLASH, 0, FLASH.Length, 0))
                    {
                        flashing = false;
                        if (port.IsOpen)
                            port.Close();
                        throw new Exception("Upload failed. Lost sync. Try Arduino!!");
                    }

                    port.Progress -= new ProgressEventHandler(port_Progress);

                    progress.Value = 100;

                    log.Info("Uploaded");

                    this.Refresh();

                    int start = 0;
                    short length = 0x100;

                    byte[] flashverify = new byte[FLASH.Length + 256];

                    lbl_status.Text = "Verify APM";
                    progress.Value = 0;
                    this.Refresh();

                    while (start < FLASH.Length)
                    {
                        progress.Value = (int)((start / (float)FLASH.Length) * 100);
                        progress.Refresh();
                        port.setaddress(start);
                        log.Info("Downloading " + length + " at " + start);
                        port.downloadflash(length).CopyTo(flashverify, start);
                        start += length;
                    }

                    progress.Value = 100;

                    for (int s = 0; s < FLASH.Length; s++)
                    {
                        if (FLASH[s] != flashverify[s])
                        {
                            CustomMessageBox.Show("Upload succeeded, but verify failed: exp " + FLASH[s].ToString("X") + " got " + flashverify[s].ToString("X") + " at " + s);
                            break;
                        }
                    }

                    lbl_status.Text = "Write Done... Waiting (17 sec)";
                }
                else
                {
                    lbl_status.Text = "Failed upload";
                    CustomMessageBox.Show("Communication Error - no connection");
                }
                port.Close();

                flashing = false;

                Application.DoEvents();

                try
                {
                    ((SerialPort)port).Open();
                }
                catch { }

                DateTime startwait = DateTime.Now;

                while ((DateTime.Now - startwait).TotalSeconds < 17)
                {
                    try
                    {
                        Console.Write(((SerialPort)port).ReadExisting().Replace("\0"," "));
                    }
                    catch { }
                    System.Threading.Thread.Sleep(1000);
                    progress.Value = (int)Math.Min(((DateTime.Now - startwait).TotalSeconds / 17 * 100),100);
                    progress.Refresh();
                }
                try
                {
                    ((SerialPort)port).Close();
                }
                catch { }

                progress.Value = 100;
                lbl_status.Text = "Done";
            }
            catch (Exception ex)
            {
                lbl_status.Text = "Failed upload"; 
                CustomMessageBox.Show("Check port settings or Port in use? " + ex);
                port.Close();
            }
            flashing = false;
            MainV2.giveComport = false;
        }

        void port_Progress(int progress,string status)
        {
            log.InfoFormat("Progress {0} ", progress);
            this.progress.Value = progress;
            this.progress.Refresh();
        }

        byte[] readIntelHEXv2(StreamReader sr)
        {
            byte[] FLASH = new byte[1024 * 1024];

            int optionoffset = 0;
            int total = 0;
            bool hitend = false;

            while (!sr.EndOfStream)
            {
                progress.Value = (int)(((float)sr.BaseStream.Position / (float)sr.BaseStream.Length) * 100);
                progress.Refresh();

                string line = sr.ReadLine();

                if (line.StartsWith(":"))
                {
                    int length = Convert.ToInt32(line.Substring(1, 2), 16);
                    int address = Convert.ToInt32(line.Substring(3, 4), 16);
                    int option = Convert.ToInt32(line.Substring(7, 2), 16);
                    log.InfoFormat("len {0} add {1} opt {2}", length, address, option);

                    if (option == 0)
                    {
                        string data = line.Substring(9, length * 2);
                        for (int i = 0; i < length; i++)
                        {
                            byte byte1 = Convert.ToByte(data.Substring(i * 2, 2), 16);
                            FLASH[optionoffset + address] = byte1;
                            address++;
                            if ((optionoffset + address) > total)
                                total = optionoffset + address;
                        }
                    }
                    else if (option == 2)
                    {
                        optionoffset = (int)Convert.ToUInt16(line.Substring(9, 4), 16) << 4;
                    }
                    else if (option == 1)
                    {
                        hitend = true;
                    }
                    int checksum = Convert.ToInt32(line.Substring(line.Length - 2, 2), 16);

                    byte checksumact = 0;
                    for (int z = 0; z < ((line.Length - 1 - 2) / 2); z++) // minus 1 for : then mins 2 for checksum itself
                    {
                        checksumact += Convert.ToByte(line.Substring(z * 2 + 1, 2), 16);
                    }
                    checksumact = (byte)(0x100 - checksumact);

                    if (checksumact != checksum)
                    {
                        CustomMessageBox.Show("The hex file loaded is invalid, please try again.");
                        throw new Exception("Checksum Failed - Invalid Hex");
                    }
                }
                //Regex regex = new Regex(@"^:(..)(....)(..)(.*)(..)$"); // length - address - option - data - checksum
            }

            if (!hitend)
            {
                CustomMessageBox.Show("The hex file did no contain an end flag. aborting");
                throw new Exception("No end flag in file");
            }

            Array.Resize<byte>(ref FLASH, total);

            return FLASH;
        }

        private void FirmwareVisual_FormClosing(object sender, FormClosingEventArgs e)
        {
            if (flashing == true)
            {
                e.Cancel = true;
                CustomMessageBox.Show("Cant exit while updating");
            }
        }

        private void BUT_setup_Click(object sender, EventArgs e)
        {
            Form temp = new Form();
            MyUserControl configview = new GCSViews.ConfigurationView.Setup();
            temp.Controls.Add(configview);
            ThemeManager.ApplyThemeTo(temp);
            // fix title
            temp.Text = configview.Name;
            // fix size
            temp.Size = configview.Size;
            configview.Dock = DockStyle.Fill;
            temp.FormClosing += configview.Close;
            temp.ShowDialog();
        }

        private void pictureBoxOctav_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Octav-");
        }

        private void pictureBoxOcta_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-Octa-");
        }

        private void pictureBoxAPHil_Click(object sender, EventArgs e)
        {
            findfirmware("Firmware/APHIL-");
        }

        private void pictureBoxACHil_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-QUADHIL-");
        }

        private void pictureBoxACHHil_Click(object sender, EventArgs e)
        {
            findfirmware("AC2-HELHIL-");
        }

        private void pictureBoxAPHil_MouseEnter(object sender, EventArgs e)
        {

        }

        private void pictureBoxAPHil_MouseLeave(object sender, EventArgs e)
        {

        }
    }
}