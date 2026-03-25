#if defined _class_cplayer_
  #endinput
#endif
#define _class_cplayer_

enum struct CPlayer
{
	bool bFlagged;
	
	int iJumps;
	int iHyperJumps;
	int iHackJumps;
	int aJumps[3];
	
	CStreak hStreak;
	ArrayList hStreaks;

	void Reset()
	{
		this.bFlagged = false;
		this.iJumps = 0;
		this.iHyperJumps = 0;
		this.iHackJumps = 0;
		this.aJumps = { 0, 0, 0 };

		if (this.hStreaks != null)
		{
			CStreak hStreak;
			for (int i = 0; i < this.hStreaks.Length; i++)
			{
				this.hStreaks.GetArray(i, hStreak, sizeof(CStreak));
				hStreak.Reset();
			}
			delete this.hStreaks;
		}

		this.hStreak.Reset();
	}
}
