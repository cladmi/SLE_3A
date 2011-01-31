function [poles] = calc_pole(T,kp_teta,ki_teta,l)

a= 1 + (kp_teta/l) * T + (ki_teta/l) * T.*T;
b= -2 - (kp_teta/l) * T;
c= 1 ;
delta= b.*b - 4 * a .* c;
if delta > 0
    pole1=(-b+sqrt(delta))./(2.*a);
    pole2=(-b-sqrt(delta))./(2.*a);
else
    pole1=(-b + i*sqrt(abs(delta)))./(2 .* a);
    pole2=(-b - i*sqrt(abs(delta)))./(2 .* a);
end
poles=[pole1 ; pole2];
end

