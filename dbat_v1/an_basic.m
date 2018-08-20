d = load('C:\Users\jmcin\Local\gitprojects\ptb_experiments\dbat_v1\data\fres_180820125323_SUB00_00.mat');
d = d.data;
clf;hold on;
plot([d.result.upper_bound_inst]);
plot([d.result.x],'g');
plot([d.result.x_obs], 'g--');
plot([d.result.lower_bound_inst]);