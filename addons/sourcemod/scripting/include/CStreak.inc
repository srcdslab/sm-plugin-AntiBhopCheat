#if defined _class_cstreak_
  #endinput
#endif
#define _class_cstreak_

methodmap CStreak < Basic
{
	public CStreak()
	{
		Basic myclass = new Basic();

		myclass.SetBool("bValid", false);
		myclass.SetInt("iStartTick", -1);
		myclass.SetInt("iEndTick", -1);
		myclass.SetFloat("fStartVel", 0.0);
		myclass.SetFloat("fEndVel", 0.0);

		myclass.SetInt("iJumps", 0);
		myclass.SetInt("iHyperJumps", 0);
		myclass.SetInt("iHackJumps", 0);
		myclass.SetArray("aJumps", {0, 0, 0}, 3);

		myclass.SetHandle("hJumps", new ArrayList(1));

		return view_as<CStreak>(myclass);
	}

	property bool bValid
	{
		public get()
		{
			return this.GetBool("bValid");
		}
		public set(bool value)
		{
			this.SetBool("bValid", value);
		}
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

	property int iJumps
	{
		public get()
		{
			return this.GetInt("iJumps");
		}
		public set(int value)
		{
			this.SetInt("iJumps", value);
		}
	}

	property int iHyperJumps
	{
		public get()
		{
			return this.GetInt("iHyperJumps");
		}
		public set(int value)
		{
			this.SetInt("iHyperJumps", value);
		}
	}

	property int iHackJumps
	{
		public get()
		{
			return this.GetInt("iHackJumps");
		}
		public set(int value)
		{
			this.SetInt("iHackJumps", value);
		}
	}

	public void GetJumps(int value[3])
	{
		this.GetArray("aJumps", value, sizeof(value));
	}

	public void SetJumps(const int value[3])
	{
		this.SetArray("aJumps", value, sizeof(value));
	}

	property ArrayList hJumps
	{
		public get()
		{
			return view_as<ArrayList>(this.GetHandle("hJumps"));
		}
		public set(ArrayList value)
		{
			this.SetHandle("hJumps", value);
		}
	}

	public void Dispose(bool disposemembers=true)
	{
		if(disposemembers)
		{
			ArrayList hJumps = this.hJumps;

			for(int i = 0; i < hJumps.Length; i++)
			{
				CJump hJump = view_as<CJump>(hJumps.Get(i));
				hJump.Dispose();
			}

			delete hJumps;
		}

		delete this;
	}
}
