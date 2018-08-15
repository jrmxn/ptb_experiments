function sessionStart(varargin)
%%
%
d.maxtime = Inf;
d.t_rot = 0.02;%time to rotate
d.deg_max = 45;
d.debugMode = true;
d.useMouseClicks = false;
d.lower_fixate = 35;
d.upper_fixate = 45;
d.lower_fixate = 5;
d.upper_fixate = 6;
d.crossL = 16;%unit: pixels. Should be 6 degrees. Needs calculating depdent on physical monitor size and resolution.
d.crossW = d.crossL/8;
d.saveDir = fullfile(pwd,'data');
d.lower_bound = 200;
d.upper_bound = 1000;
d.state_gain = 10;
d.state_noise = 5;
d.rt_max = 0.8;
%% Parse inputs
v = inputParser;
fn_d = fieldnames(d);
for ix_d = 1:length(fn_d)
    addParameter(v,fn_d{ix_d},d.(fn_d{ix_d}));
end
parse(v,varargin{:});
data.protocol = v.Results;clear d;
%% Setup the fixation state
pd_fixate = makedist('Uniform', 'lower', data.protocol.lower_fixate, 'upper', data.protocol.upper_fixate);
%%
[~,hostname] = system('hostname');
data.hostname = strtrim(hostname);
rng('shuffle');
%% Get experimental condition...
tagroot = 'sub00';
ix_session = 0;
if not(data.protocol.debugMode)
    % n_elements_tag = 5;
    % while numel(tagroot)~=n_elements_tag
    prompt = 'What is the subject''s tag? ';
    tagroot = input(prompt,'s');
    %     if numel(tagroot)~=n_elements_tag
    %         fprintf('Tag was not five letters.\n\n');
    %     end
    % end
    %%
    string_ix_session = '0';
    while (strcmpi(string_ix_session,'0'))
        prompt = 'Please enter the session number: ';
        string_ix_session = input(prompt,'s');
        ix_session = str2double(string_ix_session);
        %This should really be the def of the while but don't want to
        %change.
        if ~ismember(ix_session,[1:9])
            error('Invalid input.');
        end
    end
end
data.protocol.session = ix_session;
%%
data.protocol.tagroot = upper(tagroot);
%% Keyboard
KbName('UnifyKeyNames');
escapeKey = KbName('ESCAPE');
if ~data.protocol.useMouseClicks
    doKey = KbName('s');
    upKey = KbName('w');
    leKey = KbName('a');
    riKey = KbName('d');
    plusKey =  KbName('+');
    spaceKey = KbName('space');
    scanListK = zeros(256,1);scanListK([spaceKey escapeKey plusKey doKey upKey leKey riKey]) = 1;
else
    scanListK = zeros(256,1);scanListK([spaceKey escapeKey]) = 1;
    [~,~,keyCodeMouse] = GetMouse;
    n_mouse_buttons = length(keyCodeMouse);
    leKey = 1;
    riKey = n_mouse_buttons;
    MouseName{1} = 'LMouse';
    MouseName{n_mouse_buttons} = 'RMouse';
end
[~,~,keyCode] = KbCheck([],scanListK);

%% Final check
fprintf('Press Ctrl-C to cancel. Press the ESC key to cotinue...\n')
while (~logical(keyCode(escapeKey)))
    [~,keyCode] = KbWait([], 3);
end
fprintf('OK.\n')
pause(0.5);
[~,~,keyCode] = KbCheck([],scanListK);
%%
try
    timeStart = GetSecs;
    data.timeStart = timeStart;
    data.protocol.timeStartString = datestr(datetime('now'),'yymmddHHMMSS');
    ix_trial = 0;
    if data.protocol.debugMode
        Screen('Preference', 'SkipSyncTests', 1);
    end
    %% Screen
    whichScreen = 0;
    [w, rect] = Screen('Openwindow',whichScreen,[0,0,0]);%,[],[],2);
    ifi = Screen('GetFlipInterval', w);
    data.protocol.W = rect(RectRight); % screen width
    data.protocol.H = rect(RectBottom); % screen height
    drawCross(w, data.protocol.crossL, data.protocol.crossW, 0)
    % Screen(w,'FillRect',data.display.backgroundColor);
    Screen('Flip', w);
    %%
    WaitSecs(0.1);
    %%
    firstStateEntrance = true;
    currentState = 'fixate';
    data.result = [];
    upper_bound_inst = v.upper_bound;
    lower_bound_inst = v.lower_bound;
    x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
    
    %%
    while ~logical(keyCode(escapeKey))
        [keyIsDown,atimeNow,keyCode] = KbCheck([],scanListK);
        timeNow = atimeNow - timeStart;
        if data.protocol.useMouseClicks
            [~,~,keyCodeMouse] = GetMouse;
            error('Not fully implemented');
        end
        %% State changes
        if strcmpi(currentState,'fixate')
            if firstStateEntrance
                firstStateEntranceTime = timeNow;
                firstStateEntrance = false;
                drawCross(w, data.protocol.crossL, data.protocol.crossW, 0)
                enable_stimulus = true;
                listen_for_response = true;
                leaveState = false;
                
                ix_trial = ix_trial + 1;
                x_obs = x + d.state_noise;
                
                data.result(ix_trial).x = x;
                data.result(ix_trial).x_obs = x_obs;
                data.result(ix_trial).rt = nan;
                data.result(ix_trial).upper_bound_inst = upper_bound_inst;
                data.result(ix_trial).lower_bound_inst = lower_bound_inst;
                data.result(ix_trial).choice = -1;
            else
                draw.Allow = false;
                if (timeNow - firstStateEntranceTime)>v.rt_max
                    leaveState = true;
                end
                
                if keyIsDown&&listen_for_response&&(ix_trial>1)
                    % the RT is associated with previous trialTime so -1
                    data.result(ix_trial).rt = timeNow-firstStateEntranceTime;
                    if logical(keyCode(upKey))
                        data.result(ix_trial).choice = +1;
                        %                     elseif logical(keyCode(doKey))
                        %                         data.result(ix_trial).choice = -1;
                    else
                        data.result(ix_trial).choice = nan;
                    end
                    listen_for_response = false;
                end
            end
            
            if leaveState
                currentState = 'feedback';
                firstStateEntrance = true;
                if timeNow>data.protocol.maxtime
                    keyCode(escapeKey) = true;
                end
            end
        elseif strcmpi(currentState,'feedback')
            if firstStateEntrance
                firstStateEntranceTime = timeNow;
                firstStateEntrance = false;
                leaveState = false;
                draw.Allow = true;
                reset_state = false;
                enable_feedback = true;
                %update the state based on the choice
                x = x + v.state_gain*data.result(ix_trial).choice;
                if x > upper_bound_inst
                    %shock!
                    reset_state = true;
                elseif x < lower_bound_inst
                    %shock!
                    reset_state = true;
                end
            end
            
            t_now = timeNow - firstStateEntranceTime;
            if t_now > 0.3
                leaveState = true;
            end
            
            if leaveState
                currentState = 'fixate';
                firstStateEntrance = true;
                if reset_state
                    x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
                end
            end
        end
        if enable_stimulus
            %start playing stimulus
            enable_stimulus = false;
        elseif enable_feedback
            %start playing feedback
            enable_feedback = false;
        end
        %% Screen update
        if draw.Allow
            vbl = Screen('Flip', w);
        end
        
    end
    cleanup(data,false);
catch
    cleanup(data,true);
    
end

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Subfunctions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cleanup(data, errorHappened)
if not(exist(data.protocol.saveDir,'dir')==7)
    mkdir(data.protocol.saveDir);
end
f_name = sprintf('fres_%s_%s_%02d', data.protocol.timeStartString, data.protocol.tagroot, data.protocol.session);
f_out = fullfile(data.protocol.saveDir,f_name);
save(f_out,'data');
sca;

if errorHappened
    psychrethrow(psychlasterror);
end
end

function drawCross(window, W, L, theta)
rect_array = ones(L, W, 3)*255;
t1=Screen('MakeTexture',window,rect_array);
t2=Screen('MakeTexture',window,rect_array);
Screen('DrawTexture',window,t1,[],[],theta);
Screen('DrawTexture',window,t2,[],[],theta+90);
end