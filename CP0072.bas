' LS501 Copyright Cyrob 2016
' CP0072 Firmware

' Release History
' 17/07/2016	V1.0 		Phildem		Creation Proto
' 22/10/2016	V1.1 		Phildem		Final Release

' IO abstraction
symbol Out_Data		= B.1		'Ser_Data
symbol Out_Clock		= B.2		'Ser_Clock Activ Rising Edge
symbol Out_Strobe		= B.3		'Ser_Strobe Activ falling Edge
symbol In_HpCtl 		= pinB.4	'HP On/Off Button activ Low
symbol In_Hp48 		= pinB.5	'HP 4/8 Ohm Button activ Low
symbol Out_Piezzo		= C.0		'Piezzo
symbol In_DcNeg 		= pinC.1	'HP DC Detection Neg activ Low
symbol In_DcPos 		= pinC.2	'HP DC Detection Pos activ Low
symbol In_Log		= pinC.3	'Lin/Log Button activ Low
symbol ADC_HP		= C.4		'Voltage at HP 0->4.5V 

' Misc Constant
symbol kCkPulse 		= 2		' Clock Pulse Time
symbol kCkPause	 	= 2		' Interclock Time
symbol kBarMaxHold 	= 15		' Max Segment hold in 100mS inc
symbol kNbMaxSecu 	= 3		' Number of loop at max to switch off

'Variables
symbol m_bLog		= bit0	' Set If Log Display
symbol m_b4ohm		= bit1	' Set If 4 ohm Mode
symbol m_bOn		= bit2	' Set If OutPut On
symbol m_bDCPos		= bit3	' Set if Dc Pos Detect
symbol m_bDCNeg		= bit4	' Set if Dc Neg Detect

symbol m_AllBit		= b0		' bit 0-bit7 as byte		

symbol m_Bar 		= b2		' Bar Value 0->10 
symbol m_BarPeak		= b3		' Bar Peak 0->10 
symbol m_DisLp		= b4		' DisLoop 
symbol m_HP			= b5		' HP Value
symbol m_MaxTmp		= b6		' Max live counter
symbol m_NbMax		= b7		' NbMax Counter
symbol m_Tsk1Loop		= b8		' Task 1 Loop

symbol m_WMul		= w8		' 4 Ohm Power correction calculation


'Main task********************************************************************************
start0:

m_AllBit 	= 0	' Clear allbit Var
m_NbMax 	= 0	' Secu must be init

Low Out_Clock
Low Out_Strobe

'Test BarGraph segments
for m_Bar = 1 to 10
	Gosub Ser_Out	
	sound Out_Piezzo,(0,5,100,3)
next m_Bar

sound Out_Piezzo,(120,20)
sound Out_Piezzo,(50,20)

resume 1		' Max refresh task On
resume 2		' I/O Panel task On
resume 3		' Secu Loop task On

SwLoop:

readadc ADC_HP,m_HP	'Read Hp voltage

if m_b4ohm = 1 then	'if 4 Ohm, a correction must be applied for 2W Full scale
	m_WMul=m_HP
	m_WMul=m_WMul*10
	m_HP=m_WMul/14
endif

if m_bLog =1 then		' Log Display done by discrete value test
	m_Bar=0
	
	if m_HP>8 then
		m_Bar=1
	endif

	if m_HP>11 then
		m_Bar=2
	endif

	if m_HP>16 then
		m_Bar=3
	endif
		
	if m_HP>23 then
		m_Bar=4
	endif
		
	if m_HP>32 then
		m_Bar=5
	endif
		
	if m_HP>45 then
		m_Bar=6
	endif
		
	if m_HP>64 then
		m_Bar=7
	endif	
		
	if m_HP>90 then
		m_Bar=8
	endif
		
	if m_HP>127 then
		m_Bar=9
	endif
		
	if m_HP>178 then
		m_Bar=10
	endif
else
	m_Bar=m_HP/18	'Lin Scale Correction
endif
	
if m_Bar>=m_BarPeak then	'Calc Peak
	m_MaxTmp=0
	m_BarPeak=m_Bar
	
	if m_BarPeak>=10 and m_bOn = 1 then
		inc m_NbMax
	else
		m_NbMax=0
	endif	
endif

Gosub Ser_Out
Goto SwLoop

'Max reset task********************************************************************************
' This task if to handle Max display timeout and switch off LS if overloaded
start1:
suspend 1	' Wait init

ResetMax:
Pause 100
inc m_MaxTmp
if m_MaxTmp>=kBarMaxHold then
	m_MaxTmp=0
	m_BarPeak=0
endif

if m_NbMax>=kNbMaxSecu then
	m_bOn=0
	Gosub Ser_Out	' Switch of out asap
	
	m_NbMax=0
	
	' Alarm Sound
	for m_Tsk1Loop = 1 to 10
		sound Out_Piezzo,(80,5,100,5)
	next m_Tsk1Loop	

endif
	

Goto ResetMax

'Button Loop********************************************************************************
' This task if to handle the panel Button
start2:
suspend 2	' Wait init

BtLoop:

'Look If Log
if In_Log=0 then
	sound Out_Piezzo,(120,10)
	m_bLog=not m_bLog
	WLog0:
	if In_Log=0 then
		goto WLog0
	endif
endif
	
'Look If On
if In_HpCtl=0 and m_bDCPos = 0 and m_bDCNeg = 0 then
	sound Out_Piezzo,(120,10)
	m_bOn=not m_bOn
	WOn0:
	if In_HpCtl=0 then
		goto WOn0
	endif
endif

'Look If 4
if In_Hp48=0 then
	sound Out_Piezzo,(120,10)
	m_b4ohm=not m_b4ohm
	W480:
	if In_Hp48=0 then
		goto W480
	endif
endif

Goto BtLoop


'Secu Loop********************************************************************************
' This task if to handle the DC securities
start3:
suspend 3	' Wait init

SecuLoop:

	m_bDCNeg=not In_DcNeg
	m_bDCPos=not In_DcPos
	
	' Look for On and switch off if it's set
	
	 if  m_bDCPos=1 or m_bDCNeg=1 then
		if m_bOn=1 then
			m_bOn=0
			Gosub Ser_Out	' Switch of out asap
			sound Out_Piezzo,(120,15,115,10,110,5,0,10,120,10,0,10,120,10)
			endif
		endif

Goto SecuLoop

'Refresh output ==============================================================
Ser_Out:
'Display
for m_DisLp = 1 to 10
	
	if m_DisLp<=m_Bar or m_DisLp=m_BarPeak then
		High Out_Data
	else
		Low Out_Data
	endif
	
	pulsout Out_Clock,kCkPulse
	PAUSEUS kCkPause
next m_DisLp

'Led HPOn~~~~~~~~~~~~~~~~~~~~~~
if m_bOn = 1 then
	High Out_Data
else
	Low Out_Data
endif
	
pulsout Out_Clock,kCkPulse
PAUSEUS kCkPause

'Led DCNeg ~~~~~~~~~~~~~~~~~~~~~~
if m_bDCNeg = 1 then
	High Out_Data
else
	Low Out_Data
endif
	
pulsout Out_Clock,kCkPulse
PAUSEUS kCkPause

'Led DCPos ~~~~~~~~~~~~~~~~~~~~~~
if m_bDCPos = 1 then
	High Out_Data
else
	Low Out_Data
endif

pulsout Out_Clock,kCkPulse
PAUSEUS kCkPause

'Relay 4 ohm ~~~~~~~~~~~~~~~~~~~~~~
if m_b4ohm = 1 then
	High Out_Data
else
	Low Out_Data
endif

pulsout Out_Clock,kCkPulse
PAUSEUS kCkPause

'Relay Out ~~~~~~~~~~~~~~~~~~~~~~
if m_bOn = 1 then
	High Out_Data
else
	Low Out_Data
endif

pulsout Out_Clock,kCkPulse
PAUSEUS kCkPause

'Led Led Log ~~~~~~~~~~~~~~~~~~~~~~
if m_bLog = 1 then
	High Out_Data
else
	Low Out_Data
endif

pulsout Out_Clock,kCkPulse
PAUSEUS kCkPause

'Strobe
pulsout Out_Strobe,kCkPulse
PAUSEUS kCkPause

return