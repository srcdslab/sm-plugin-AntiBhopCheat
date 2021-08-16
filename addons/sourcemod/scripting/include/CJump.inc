#if defined _class_cjump_
  #endinput
#endif
#define _class_cjump_

methodmap CJump < Basic
{
	public CJump()
	{
		Basic myclass = new Basic();

		myclass.SetInt("iStartTick", -1);
		myclass.SetInt("iEndTick", -1);
		myclass.SetFloat("fStartVel", 0.0);
		myclass.SetFloat("fEndVel", 0.0);

		myclass.SetInt("iPrevJump", -1);
		myclass.SetInt("iNextJump", -1);

		myclass.SetHandle("hPresses", new ArrayList(2));

		return view_as<CJump>(myclass);
	}

	property int iStartTick
	{
		public get()
		{
			return this.GetInt("iStartTick");
		}
		public set(int value)
		{
			this.SetInt("iStartTick", value);
		}
	}

	property int iEndTick
	{
		public get()
		{
			return this.GetInt("iEndTick");
		}
		public set(int value)
		{
			this.SetInt("iEndTick", value);
		}
	}

	property float fStartVel
	{
		public get()
		{
			return this.GetFloat("fStartVel");
		}
		public set(float value)
		{
			this.SetFloat("fStartVel", value);
		}
	}

	property float fEndVel
	{
		public get()
		{
			return this.GetFloat("fEndVel");
		}
		public set(float value)
		{
			this.SetFloat("fEndVel", value);
		}
	}

	property int iPrevJump
	{
		public get()
		{
			return this.GetInt("iPrevJump");
		}
		public set(int value)
		{
			this.SetInt("iPrevJump", value);
		}
	}

	property int iNextJump
	{
		public get()
		{
			return this.GetInt("iNextJump");
		}
		public set(int value)
		{
			this.SetInt("iNextJump", value);
		}
	}

	property ArrayList hPresses
	{
		public get()
		{
			return view_as<ArrayList>(this.GetHandle("hPresses"));
		}
		public set(ArrayList value)
		{
			this.SetHandle("hPresses", value);
		}
	}

	public void Dispose(bool disposemembers=true)
	{
		if(disposemembers)
		{
			delete this.hPresses;
		}

		delete this;
	}
}
