d = load('C:\Users\jmcin\Local\gitprojects\ptb_experiments\dbat_v1\data\temp_data.mat');
d = d.data;
clf;hold on;
plot([d.result.upper_bound_inst]);
plot([d.result.x]);
plot([d.result.x_obs]);
plot([d.result.lower_bound_inst]);