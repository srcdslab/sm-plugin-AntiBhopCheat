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
		this.bValid = false;
		this.iStartTick = -1;
		this.iEndTick = -1;
		this.fStartVel = 0.0;
		this.fEndVel = 0.0;
		
		this.iJumps = 0;
		this.iHyperJumps = 0;
		this.iHackJumps = 0;
		this.aJumps = { 0, 0, 0 };

		if (this.hJumps != null)
		{
			for (int i = 0; i < this.hJumps.Length; i++)
			{
				CJump hJump;
				this.hJumps.GetArray(i, hJump, sizeof(CJump));
				hJump.Reset();
			}
			delete this.hJumps;
		}
	}
}
