clc, clear
n=10;
M=256
samp = 0:2^n-1;

phi0 = samp(2^n/2+1);
A_cos = cos(pi/(2^(n-1)).*samp);
A_sin = sin(pi/(2^(n-1)).*samp);
%  plot(0:2^n-1,A_sin ), grid on, hold on

x = 0:(pi/(2^(n-1))):2*pi-(pi/(2^(n-1)));
sg_i =(2^(n-1))*(sin (x));
sg_i =sg_i(1:2^(n-2));
diskrA_d = fix(sg_i);
diskrA_b = dec2bin(diskrA_d);
disp(diskrA_b)
diskrA_hex = dec2hex(diskrA_d);
disp(diskrA_hex);
plot(diskrA_d)
