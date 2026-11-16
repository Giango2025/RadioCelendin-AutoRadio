using System;
using System.Drawing;
using System.Windows.Forms;

namespace AutoRadio;
public sealed record Choice(string Code, string Label)
{
    public override string ToString() => Label;
}
public static class Ui
{
    public static DataGridView Grid() => new()
    {
        Dock=DockStyle.Fill, ReadOnly=true, AllowUserToAddRows=false,
        AllowUserToDeleteRows=false, SelectionMode=DataGridViewSelectionMode.FullRowSelect,
        MultiSelect=false, AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill,
        BackgroundColor=Color.White, RowHeadersVisible=false, BorderStyle=BorderStyle.FixedSingle
    };
    public static Button Button(string caption, Action handler, int width=145)
    {
        var b=new Button { Text=caption, Width=width, Height=34, Margin=new Padding(3,4,3,4) };
        b.Click += (_,_)=>handler(); return b;
    }
    public static FlowLayoutPanel Bar(params Control[] controls)
    {
        var bar=new FlowLayoutPanel { Dock=DockStyle.Top, Height=48, FlowDirection=FlowDirection.LeftToRight,
            WrapContents=false, AutoScroll=true, Padding=new Padding(6,3,6,1) };
        bar.Controls.AddRange(controls); return bar;
    }
    public static Panel Page(Control main, params Control[] top)
    {
        var panel=new Panel { Dock=DockStyle.Fill };
        main.Dock=DockStyle.Fill; panel.Controls.Add(main);
        foreach (var c in top) { c.Dock=DockStyle.Top; panel.Controls.Add(c); }
        return panel;
    }
    public static TextBox Text(string value="") => new() { Text=value, Width=320 };
    public static NumericUpDown Number(decimal value=0, decimal min=0, decimal max=100000) => new()
        { Value=Math.Clamp(value,min,max), Minimum=min,Maximum=max,Width=180 };
    public static ComboBox Combo(params string[] values)
    {
        var c=new ComboBox { DropDownStyle=ComboBoxStyle.DropDownList,Width=320 };
        c.Items.AddRange(values); if (values.Length>0)c.SelectedIndex=0; return c;
    }
    public static DateTimePicker Date(DateTime? value=null, bool dateTime=false) => new()
    {
        Width=320,Value=value ?? DateTime.Now,Format=DateTimePickerFormat.Custom,
        CustomFormat=dateTime?"dd/MM/yyyy HH:mm":"dd/MM/yyyy", ShowUpDown=dateTime
    };
    public static bool Dialog(IWin32Window owner,string title,params (string Label,Control Input)[] fields)
    {
        using var f=new Form { Text=title,ClientSize=new Size(560,Math.Min(680,105+fields.Length*56)),
            StartPosition=FormStartPosition.CenterParent,FormBorderStyle=FormBorderStyle.FixedDialog,
            MaximizeBox=false,MinimizeBox=false,ShowInTaskbar=false };
        var layout=new TableLayoutPanel { Dock=DockStyle.Fill, ColumnCount=2, RowCount=fields.Length+1,
            Padding=new Padding(15),AutoScroll=true };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,170));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
        for(int i=0;i<fields.Length;i++)
        {
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute,53));
            var label=new Label { Text=fields[i].Label,AutoSize=false,TextAlign=ContentAlignment.MiddleLeft,Dock=DockStyle.Fill };
            var control=fields[i].Input;control.Anchor=AnchorStyles.Left|AnchorStyles.Right;
            layout.Controls.Add(label,0,i);layout.Controls.Add(control,1,i);
        }
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute,54));
        var save=new Button { Text="Guardar",DialogResult=DialogResult.OK,Width=110 };
        var cancel=new Button { Text="Cancelar",DialogResult=DialogResult.Cancel,Width=110 };
        var buttons=new FlowLayoutPanel { Dock=DockStyle.Fill,FlowDirection=FlowDirection.RightToLeft };
        buttons.Controls.Add(cancel);buttons.Controls.Add(save);
        layout.Controls.Add(buttons,0,fields.Length);layout.SetColumnSpan(buttons,2);
        f.AcceptButton=save;f.CancelButton=cancel;f.Controls.Add(layout);
        return f.ShowDialog(owner)==DialogResult.OK;
    }
    public static Choice? SelectedChoice(ComboBox combo) => combo.SelectedItem as Choice;
    public static string? SelectedString(DataGridView grid,string column)
    {
        if(grid.CurrentRow?.DataBoundItem is not System.Data.DataRowView r || !r.Row.Table.Columns.Contains(column)) return null;
        return Convert.ToString(r[column]);
    }
    public static int? SelectedInt(DataGridView grid,string column)
    {
        var s=SelectedString(grid,column);return int.TryParse(s,out var n)?n:null;
    }
}
