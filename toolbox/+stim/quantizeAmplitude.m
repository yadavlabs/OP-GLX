function [kc, ka, I_valid, Ic, Ia] = quantizeAmplitude(amplitude, Nc, Na, s)
%QUANTIZEAMPLITUDE Summary of this function goes here
%   Detailed explanation goes here
arguments (Input)
    amplitude % desired amplitude (uA)
    Nc % number of cathodes
    Na % number of anodes
    s  % current step size (uA)
end

arguments (Output)
    kc % quantized balanced cathode amplitude
    ka % quantized balanced anode amplitude
    I_valid % valid amplitude based on constraints (equal to input "amplitude" if constraints end up being met)
    Ic % amplitude for cathodes (uA)
    Ia % amplitude for anodes (uA)
end


q = Nc * Na * s; % number of cathodes, number of anodes, step size must be factors of amplitude
r = amplitude / q;

m = round(amplitude / (q)); % round off to guarantee above constraint
I_valid = m * q; % corrected valid amplitdue (will be the same as amplitude if m is an integer before rounding)

kc = m * Na; % quantized amplitude for cathodes
ka = m * Nc; % quantized amplitude for anodes

Ic = kc * s; % cathode amplitude (uA)
Ia = ka * s; % anode amplitude (uA)


end