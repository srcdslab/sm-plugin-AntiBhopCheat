#if defined _class_cplayer_
  #endinput
#endif
#define _class_cplayer_

methodmap CPlayer < Basic
{
	public CPlayer(int client)
	{
		Basic myclass = new Basic();

		myclass.SetInt("iClient", client);
		myclass.SetBool("bFlagged", false);

		myclass.SetInt("iJumps", 0);
		myclass.SetInt("iHyperJumps", 0);
		myclass.SetInt("iHackJumps", 0);
		myclass.SetArray("aJumps", {0, 0, 0}, 3);

		myclass.SetHandle("hStreak", new CStreak());
		myclass.SetHandle("hStreaks", new ArrayList(1));

		return view_as<CPlayer>(myclass);
	}

	property int iClient
	{
		public get()
		{
			return this.GetInt("iClient");
		}
		public set(int value)
		{
			this.SetInt("iClient", value);
		}
	}

	property bool bFlagged
	{
		public get()
		{
			return this.GetBool("bFlagged");
		}
		public set(bool value)
		{
			this.SetBool("bFlagged", value);
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

	property CStreak hStreak
	{
		public get()
		{
			return view_as<CStreak>(this.GetHandle("hStreak"));
		}
		public set(CStreak value)
		{
			this.SetHandle("hStreak", value);
		}
	}

	property ArrayList hStreaks
	{
		public get()
		{
			return view_as<ArrayList>(this.GetHandle("hStreaks"));
		}
		public set(ArrayList value)
		{
			this.SetHandle("hStreaks", value);
		}
	}

	public void Dispose(bool disposemembers=true)
	{
		if(disposemembers)
		{
			ArrayList hStreaks = this.hStreaks;

			CStreak hStreak;
			for(int i = 0; i < hStreaks.Length; i++)
			{
				hStreak = view_as<CStreak>(hStreaks.Get(i));
				hStreak.Dispose();
			}

			delete hStreaks;

			if(this.hStreak != hStreak)
				this.hStreak.Dispose();
		}

		delete this;
	}
}
