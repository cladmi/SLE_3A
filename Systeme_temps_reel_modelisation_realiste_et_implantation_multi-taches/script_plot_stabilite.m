x=0:0.05:100;
res=calc_pole(x,ki_teta,kp_teta,l);
plot(real(res(1,:)),imag(res(1,:)),'--rs');
plot(real(res(2,:)),imag(res(2,:)),'--rs');
