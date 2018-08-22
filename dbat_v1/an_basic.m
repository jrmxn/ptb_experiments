d_loc = dir('data');
d_loc = d_loc(contains({d_loc.name},'fres'));
[~,ix] = max([d_loc.datenum]);
d_loc = d_loc(ix);
d = load(fullfile(d_loc.folder, d_loc.name));

d = load(fullfile('data', 'fres_180822104533_SUB00_00.mat'));
d = d.data;
clf;hold on;
plot([d.result.upper_bound_inst]);
plot([d.result.x],'g');
plot([d.result.x_obs], 'g--');
plot([d.result.lower_bound_inst]);