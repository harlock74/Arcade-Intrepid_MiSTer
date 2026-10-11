// Zero-valued status defaults map to parent MAME DSW=4f and clockwise portrait.
localparam CONF_STR = {
    "A.INTREPID;;",
    "H0O1,Orientation,Portrait,Native;",
    "O23,Aspect Ratio,Original,Full screen,[ARC1],[ARC2];",
    "H1O4,Analog Output,Native,Scaler;",
    "-;",
    "O9,Demo Sounds,On,Off;",
    "OA,Cabinet,Upright,Cocktail;",
    "OB,Difficulty,Easy,Hard;",
    "OC,Bonus Life,10000,30000;",
    "OD,Lives,5,3;",
    "OEF,Coinage,1 Coin 1 Credit,2 Coins 1 Credit,1 Coin 2 Credits,Free Play;",
    "O8,Invulnerability,Off,On;",
    "-;",
    "OG,Autosave Hiscores,Off,On;",
`ifdef INTREPID_HS_DIAG
    "OH,Diagnostic trace,Record,Freeze;",
`endif
    "OI,Pause,Off,On;",
    "R0,Reset;",
    "J1,Action,Start 1,Coin,Start 2,Pause;",
    "jn,B,Start,R,Select,L;",
    "V,v", `BUILD_DATE
};
