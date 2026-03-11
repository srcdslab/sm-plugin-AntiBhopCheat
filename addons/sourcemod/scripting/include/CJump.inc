#if defined _class_cjump_
  #endinput
#endif
#define _class_cjump_

enum struct CJump
{
	int iStartTick;
	int iEndTick;
	float fStartVel;
	float fEndVel;
	
	int iPrevJump;
	int iNextJump;
	
	ArrayList hPresses;
	
	void Reset()
	{
		this.iStartTick = -1;
		this.iEndTick = -1;
		this.fStartVel = 0.0;
		this.fEndVel = 0.0;
		
		this.iPrevJump = -1;
		this.iNextJump = -1;

		delete this.hPresses;
	}
}
