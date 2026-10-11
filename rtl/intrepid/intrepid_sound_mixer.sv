// Six pinned-MAME mono routes at 0.25. Inputs are Q15 legacy-normalized DACs.
// Each [-4096,12288]; sum [-24576,73728]; /4 [-6144,18432]. No clipping.
// Arithmetic shift rounds negative nonmultiples toward minus infinity (<1 LSB).
module intrepid_sound_mixer(
    input wire reset, enable,
    input wire signed [15:0] a,b,c,d,e,f,
    output wire signed [15:0] audio
);
    wire signed [18:0] sum={{3{a[15]}},a}+{{3{b[15]}},b}+{{3{c[15]}},c}+
        {{3{d[15]}},d}+{{3{e[15]}},e}+{{3{f[15]}},f};
    wire signed [18:0] scaled=sum>>>2;
    assign audio=(reset || !enable) ? 16'sd0 : scaled[15:0];
endmodule
