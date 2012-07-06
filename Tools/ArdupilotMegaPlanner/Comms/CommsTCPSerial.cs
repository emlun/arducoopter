﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Reflection;
using System.Text;
using System.IO.Ports;
using System.Threading;
using System.Net; // dns, ip address
using System.Net.Sockets; // tcplistner
using log4net;

namespace ArdupilotMega.Comms
{
    public class TcpSerial : ArdupilotMega.Comms.ICommsSerial
    {
        private static readonly ILog log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        TcpClient client = new TcpClient();
        IPEndPoint RemoteIpEndPoint = new IPEndPoint(IPAddress.Any, 0);
        byte[] rbuffer = new byte[0];
        int rbufferread = 0;

        int retrys = 3;

        public int WriteBufferSize { get; set; }
        public int WriteTimeout { get; set; }
        public bool RtsEnable { get; set; }

        ~TcpSerial()
        {
            this.Close();
            client = null;
        }

        public TcpSerial()
        {
            //System.Threading.Thread.CurrentThread.CurrentUICulture = new System.Globalization.CultureInfo("en-US");
            //System.Threading.Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo("en-US");

            Port = "5760";
        }

        public void toggleDTR()
        {
        }

        public string Port { get; set; }

        public int ReadTimeout
        {
            get;// { return client.ReceiveTimeout; }
            set;// { client.ReceiveTimeout = value; }
        }

        public int ReadBufferSize {get;set;}

        public int BaudRate { get; set; }
        public StopBits StopBits { get; set; }
        public  Parity Parity { get; set; }
        public  int DataBits { get; set; }

        public string PortName { get; set; }

        public  int BytesToRead
        {
            get { return client.Available + rbuffer.Length - rbufferread; }
        }

        public int BytesToWrite { get { return 0; } }

        public bool IsOpen { get { try { return client.Client.Connected; } catch { return false; } } }

        public bool DtrEnable
        {
            get;
            set;
        }

        public  void Open()
        {
            if (client.Client.Connected)
            {
                log.Warn("tcpserial socket already open");
                return;
            }

            string dest = Port;
            string host = "127.0.0.1";

            if (ArdupilotMega.MainV2.config["TCP_port"] != null)
                dest = ArdupilotMega.MainV2.config["TCP_port"].ToString();

            if (ArdupilotMega.MainV2.config["TCP_host"] != null)
                host = ArdupilotMega.MainV2.config["TCP_host"].ToString();

            if (System.Windows.Forms.DialogResult.Cancel == ArdupilotMega.Common.InputBox("remote host", "Enter host name/ip (ensure remote end is already started)", ref host))
            {
                throw new Exception("Canceled by request");
            }
            if (System.Windows.Forms.DialogResult.Cancel == ArdupilotMega.Common.InputBox("remote Port", "Enter remote port", ref dest))
            {
                throw new Exception("Canceled by request");
            }
            Port = dest;

            ArdupilotMega.MainV2.config["TCP_port"] = Port;
            ArdupilotMega.MainV2.config["TCP_host"] = host;

            client = new TcpClient(host, int.Parse(Port));

            client.NoDelay = true;
            client.Client.NoDelay = true;

            VerifyConnected();

            return;
        }

        void VerifyConnected()
        {
            if (client == null || !IsOpen)
            {
                try
                {
                    client.Close();
                }
                catch { }

                // this should only happen if we have established a connection in the first place
                if (client != null && retrys > 0)
                {
                    client.Connect(ArdupilotMega.MainV2.config["TCP_host"].ToString(), int.Parse(ArdupilotMega.MainV2.config["TCP_port"].ToString()));
                    retrys--;
                }

                throw new Exception("The socket/serialproxy is closed");
            }
        }

        public  int Read(byte[] readto,int offset,int length)
        {
            VerifyConnected();
            try
            {
                if (length < 1) { return 0; }

                return client.Client.Receive(readto, offset, length, SocketFlags.None);
            }
            catch { throw new Exception("Socket Closed"); }
        }

        public  int ReadByte()
        {
            VerifyConnected();
            int count = 0;
            while (this.BytesToRead == 0)
            {
                System.Threading.Thread.Sleep(1);
                if (count > ReadTimeout)
                    throw new Exception("NetSerial Timeout on read");
                count++;
            }
            byte[] buffer = new byte[1];
            Read(buffer, 0, 1);
            return buffer[0];
        }

        public  int ReadChar()
        {
            return ReadByte();
        }

        public  string ReadExisting() 
        {
            VerifyConnected();
            byte[] data = new byte[client.Available];
            if (data.Length > 0)
                Read(data, 0, data.Length);

            string line = Encoding.ASCII.GetString(data, 0, data.Length);

            return line;
        }

        public  void WriteLine(string line)
        {
            VerifyConnected();
            line = line + "\n";
            Write(line);
        }

        public  void Write(string line)
        {
            VerifyConnected();
            byte[] data = new System.Text.ASCIIEncoding().GetBytes(line);
            Write(data, 0, data.Length);
        }

        public  void Write(byte[] write, int offset, int length)
        {
            VerifyConnected();
            try
            {
                client.Client.Send(write, length,SocketFlags.None);
            }
            catch { }//throw new Exception("Comport / Socket Closed"); }
        }

        public  void DiscardInBuffer()
        {
            VerifyConnected();
            int size = client.Available;
            byte[] crap = new byte[size];
            log.InfoFormat("TcpSerial DiscardInBuffer {0}",size);
            Read(crap, 0, size);
        }

        public  string ReadLine() {
            byte[] temp = new byte[4000];
            int count = 0;
            int timeout = 0;

            while (timeout <= 100)
            {
                if (!this.IsOpen) { break; }
                if (this.BytesToRead > 0)
                {
                    byte letter = (byte)this.ReadByte();

                    temp[count] = letter;

                    if (letter == '\n') // normal line
                    {
                        break;
                    }


                    count++;
                    if (count == temp.Length)
                        break;
                    timeout = 0;
                } else {
                    timeout++;
                    System.Threading.Thread.Sleep(5);
                }
            }

            Array.Resize<byte>(ref temp, count + 1);

            return Encoding.ASCII.GetString(temp, 0, temp.Length);
        }

        public void Close()
        {
            try
            {
                if (client.Client.Connected)
                {
                    client.Client.Close();
                    client.Close();
                }
            }
            catch { }

            try
            {
                client.Close();
            }
            catch { }

            client = new TcpClient();
        }
    }
}
