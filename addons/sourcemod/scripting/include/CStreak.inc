#if defined _class_cstreak_
  #endinput
#endif
#define _class_cstreak_

enum struct CStreak
{
	bool bValid;
	int iStartTick;
	int iEndTick;
	float fStartVel;
	float fEndVel;
	
	int iJumps;
	int iHyperJumps;
	int iHackJumps;
	int aJumps[3];
	
	ArrayList hJumps;
	
	void Reset()
	{
		for(int i = 0; i < this.hJumps.Length; i++)
		{
			CJump hJump;
			this.hJumps.GetArray(i, hJump, sizeof(CJump));
			hJump.Reset();
		}

		delete this.hJumps;
	}
}
