; ===========================================================================
; -------------------------------------------------------------------
; CD BIOS VARIABLES
; -------------------------------------------------------------------

MSCSTOP           equ	$0002
MSCPAUSEON        equ	$0003
MSCPAUSEOFF       equ	$0004
MSCSCANFF         equ	$0005
MSCSCANFR         equ	$0006
MSCSCANOFF        equ	$0007
ROMPAUSEON        equ	$0008
ROMPAUSEOFF       equ	$0009
DRVOPEN           equ	$000A

DRVINIT           equ	$0010
MSCPLAY           equ	$0011
MSCPLAY1          equ	$0012
MSCPLAYR          equ	$0013
MSCPLAYT          equ	$0014
MSCSEEK           equ	$0015
MSCSEEKT          equ	$0016
ROMREAD           equ	$0017
ROMSEEK           equ	$0018
MSCSEEK1          equ	$0019

TESTENTRY         equ	$001E
TESTENTRYLOOP     equ	$001F
ROMREADN          equ	$0020
ROMREADE          equ	$0021

CDBCHK            equ	$0080
CDBSTAT           equ	$0081
CDBTOCWRITE       equ	$0082
CDBTOCREAD        equ	$0083
CDBPAUSE          equ	$0084
FDRSET            equ	$0085
FDRCHG            equ	$0086
CDCSTART          equ	$0087
CDCSTARTP         equ	$0088
CDCSTOP           equ	$0089
CDCSTAT           equ	$008A
CDCREAD           equ	$008B
CDCTRN            equ	$008C
CDCACK            equ	$008D
SCDINIT           equ	$008E
SCDSTART          equ	$008F
SCDSTOP           equ	$0090
SCDSTAT           equ	$0091
SCDREAD           equ	$0092
SCDPQ             equ	$0093
SCDPQL            equ	$0094
LEDSET            equ	$0095
CDCSETMODE        equ	$0096
WONDERREQ         equ	$0097
WONDERCHK         equ	$0098

CBTINIT           equ	$0000
CBTINT            equ	$0001
CBTOPENDISC       equ	$0002
CBTOPENSTAT       equ	$0003
CBTCHKDISC        equ	$0004
CBTCHKSTAT        equ	$0005
CBTIPDISC         equ	$0006
CBTIPSTAT         equ	$0007
CBTSPDISC         equ	$0008
CBTSPSTAT         equ	$0009

BRMINIT           equ	$0000
BRMSTAT           equ	$0001
BRMSERCH          equ	$0002
BRMREAD           equ	$0003
BRMWRITE          equ	$0004
BRMDEL            equ	$0005
BRMFORMAT         equ	$0006
BRMDIR            equ	$0007
BRMVERIFY         equ	$0008

;-----------------------------------------------------------------------
; BIOS ENTRY POINTS
;-----------------------------------------------------------------------

_ADRERR           equ	$00005F40
_BOOTSTAT         equ	$00005EA0
_BURAM            equ	$00005F16
_CDBIOS           equ	$00005F22
_CDBOOT           equ	$00005F1C
_CDSTAT           equ	$00005E80
_CHKERR           equ	$00005F52
_CODERR           equ	$00005F46
_DEVERR           equ	$00005F4C
_LEVEL1           equ	$00005F76
_LEVEL2           equ	$00005F7C
_LEVEL3           equ	$00005F82 ;TIMER INTERRUPT
_LEVEL4           equ	$00005F88
_LEVEL5           equ	$00005F8E
_LEVEL6           equ	$00005F94
_LEVEL7           equ	$00005F9A
_NOCOD0           equ	$00005F6A
_NOCOD1           equ	$00005F70
_SETJMPTBL        equ	$00005F0A
_SPVERR           equ	$00005F5E
_TRACE            equ	$00005F64
_TRAP00           equ	$00005FA0
_TRAP01           equ	$00005FA6
_TRAP02           equ	$00005FAC
_TRAP03           equ	$00005FB2
_TRAP04           equ	$00005FB8
_TRAP05           equ	$00005FBE
_TRAP06           equ	$00005FC4
_TRAP07           equ	$00005FCA
_TRAP08           equ	$00005FD0
_TRAP09           equ	$00005FD6
_TRAP10           equ	$00005FDC
_TRAP11           equ	$00005FE2
_TRAP12           equ	$00005FE8
_TRAP13           equ	$00005FEE
_TRAP14           equ	$00005FF4
_TRAP15           equ	$00005FFA
_TRPERR           equ	$00005F58
_USERCALL0        equ	$00005F28 ;INIT
_USERCALL1        equ	$00005F2E ;MAIN
_USERCALL2        equ	$00005F34 ;VINT
_USERCALL3        equ	$00005F3A ;NOT DEFINED
_USERMODE         equ	$00005EA6
_WAITVSYNC        equ	$00005F10
