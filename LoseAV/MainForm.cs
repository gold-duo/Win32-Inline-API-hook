/*
 * 由SharpDevelop创建。
 * 用户： droidwolf
 * 
 * 要改变这种模板请点击 工具|选项|代码编写|编辑标准头文件
 */
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using System.Runtime.InteropServices;
namespace LoseAV
{
	/// <summary>
	/// Description of MainForm.
	/// </summary>
	public partial class MainForm : Form
	{
				
		[DllImport("HookEx.dll",CharSet=CharSet.Ansi)]
		public static extern int StartHK(string fodler);
		
		[DllImport("HookEx.dll")]
		public static extern void  StopHK();
		
		[DllImport("HookEx.dll",CharSet=CharSet.Ansi)]
		public static extern int  SetDirectory(string fodler);
		
		[DllImport("HookEx.dll")]
		public static extern int  ProtectMyProcess(int isYes);
		public MainForm()
		{
			InitializeComponent();
		}
		void Button1Click(object sender, EventArgs e)
		{
			if(this.folderBrowserDialog1.ShowDialog()==System.Windows.Forms.DialogResult.OK){
				
				StartHK(this.folderBrowserDialog1.SelectedPath);
				ProtectMyProcess(1);
			}
		}
		void MainFormFormClosing(object sender, FormClosingEventArgs e)
		{
			StopHK();
		}
		void MainFormLoad(object sender, EventArgs e)
		{
			
		}
	}
}
