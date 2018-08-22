function sessionStart(varargin)
%%
%
d.maxtime = 15;
% d.t_rot = 0.02;%time to rotate
% d.deg_max = 45;
d.debugMode = true;
d.useMouseClicks = false;
% d.lower_fixate = 35;
% d.upper_fixate = 45;
% d.lower_fixate = 5;
% d.upper_fixate = 6;
d.crossL = 16;%unit: pixels. Should be 6 degrees. Needs calculating depdent on physical monitor size and resolution.
d.crossW = d.crossL/8;
d.saveDir = fullfile(pwd,'data');
d.lower_bound = 200;
d.upper_bound = 4200;
d.lower_bound_step = 0;
d.lower_bound_step_alt = 0;
d.lower_bound_step_prob = 0;
d.upper_bound_step = -0;
d.upper_bound_step_alt = 0;
d.upper_bound_step_prob = 0.5;
d.state_gain = 100;%hz/s
d.state_noise = 0;
d.rt_max = 2.0;
d.audioASIO = false;
%% Parse inputs
v = inputParser;
fn_d = fieldnames(d);
for ix_d = 1:length(fn_d)
    addParameter(v,fn_d{ix_d},d.(fn_d{ix_d}));
end
parse(v,varargin{:});
data.protocol = v.Results;clear d;
%%
if isempty(which('Screen')),error('You need to install psychtoobox!');end
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
%%
audioFs = 96e3;
audio_T = 30;
audio_t = 0:1/audioFs:audio_T;
audio_channels = 2;
% would need to use ASIO
if ~data.protocol.audioASIO
    InitializePsychSound(1);%0 tries to reduce latency
    requestedLatencyClass = 0;
    pahandle = PsychPortAudio('Open', [], [], requestedLatencyClass, audioFs, audio_channels);
else
    devix = 18;%SBAudigy5/Rx ASIO 24/96[CC00]
    InitializePsychSound(0);
    dev = PsychPortAudio('GetDevices',[],[]);
    disp(dev(devix).DefaultSampleRate)
    disp(dev(devix).DeviceName)
    if (~strcmp(dev(devix).DeviceName,'SBAudigy5/Rx ASIO 24/96[B000]'))||(~dev(devix).DefaultSampleRate == 96000)
        error('Not ASIO')
    end
    if audioFs ~= dev(devix).DefaultSampleRate
        error('Wrong sampling rate')
    end
    pahandle = PsychPortAudio('Open',dev(devix).DeviceIndex,[],2,dev(devix).DefaultSampleRate,2);
end
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
fprintf('Press a when screen is loaded...\n')

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
    %     ifi = Screen('GetFlipInterval', w);
    data.protocol.W = rect(RectRight); % screen width
    data.protocol.H = rect(RectBottom); % screen height
    drawCross(w, data.protocol.crossL, data.protocol.crossW, 0, [1,1,1])
    % Screen(w,'FillRect',data.display.backgroundColor);
    Screen('Flip', w);
    %%
    WaitSecs(0.1);
    %%
    firstStateEntrance = true;
    currentState = 'fixate';
    data.result = [];
    upper_bound_inst = data.protocol.upper_bound;
    lower_bound_inst = data.protocol.lower_bound;
    x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
    choice = 1;
    rng(string2hash([data.protocol.tagroot,data.protocol.session]));
    %% begin by going up
    while ~logical(keyCode(leKey))
        [~, ~, keyCode] = KbCheck([],scanListK);
    end
    %%
    
    while ~logical(keyCode(escapeKey))
        [keyIsDown,atimeNow,keyCode] = KbCheck([],scanListK);
        timeNow = atimeNow - timeStart;
        if data.protocol.useMouseClicks
            [~, ~, keyCodeMouse] = GetMouse;
            error('Not fully implemented');
        end
        %% State changes
        if strcmpi(currentState,'fixate')
            if firstStateEntrance
                firstStateEntranceTime = timeNow;
                firstStateEntrance = false;
                draw.Allow = true;
                drawCross(w, data.protocol.crossL, data.protocol.crossW, 0, [1,1,1]);
                
                
                listen_for_response = true;
                leaveState_fb = false;
                leaveState_choice = false;
                
                if rand > data.protocol.lower_bound_step_prob
                    lower_bound_inst = lower_bound_inst + data.protocol.lower_bound_step;
                else
                    lower_bound_inst = lower_bound_inst + data.protocol.lower_bound_step_alt;
                end
                if rand > data.protocol.upper_bound_step_prob
                    upper_bound_inst = upper_bound_inst + data.protocol.upper_bound_step;
                else
                    upper_bound_inst = upper_bound_inst + data.protocol.upper_bound_step_alt;
                end
                
                ix_trial = ix_trial + 1;
                direction = choice;
                data.result(ix_trial).direction = direction;
                data.result(ix_trial).choice = nan;
                data.result(ix_trial).rt = nan;
                data.result(ix_trial).bound = 0;
                data.result(ix_trial).upper_bound_inst = upper_bound_inst;
                data.result(ix_trial).lower_bound_inst = lower_bound_inst;
                %
                f = x + audio_t*data.protocol.state_gain*direction + randn(size(audio_t))*data.protocol.state_noise;
%                 plot(audio_t,f)
                wavedata = repmat(sin(2*pi*f.*audio_t),audio_channels,1);
                PsychPortAudio('FillBuffer',pahandle,wavedata);
                %for simplicity...
                PsychPortAudio('Start', pahandle, 1);
                firstStateEntranceTime = timeNow;
            end
            t_state_now = timeNow - firstStateEntranceTime;
            [~, ix_min] = min(abs(t_state_now-audio_t));
            x_instant = f(ix_min);
            
%             disp('X');not(logical(keyCode(leKey)))
            if not(logical(keyCode(leKey)))&&listen_for_response
                % the RT is associated with previous trialTime so -1
                data.result(ix_trial).rt = timeNow-firstStateEntranceTime;
                leaveState_choice = true;
                data.result(ix_trial).x = x_instant;
                data.result(ix_trial).rt = timeNow-firstStateEntranceTime;
                listen_for_response = false;
                disp('A');not(logical(keyCode(leKey)))
            elseif x_instant>upper_bound_inst
                leaveState_fb = true;
                data.result(ix_trial).bound = +1;
                data.result(ix_trial).x = x_instant;
                %reset xaaa
                x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
                listen_for_response = false;
                disp('B')
            elseif x_instant<lower_bound_inst
                leaveState_fb = true;
                data.result(ix_trial).bound = -1;
                data.result(ix_trial).x = x_instant;
                %reset x
                x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
                listen_for_response = false;
                disp('C')
            end
            
            if leaveState_fb
                currentState = 'feedback';
                firstStateEntrance = true;
                PsychPortAudio('Stop', pahandle, 1);
            elseif leaveState_choice
                currentState = 'choice';
                firstStateEntrance = true;
                PsychPortAudio('Stop', pahandle, 1);
            elseif timeNow>data.protocol.maxtime
                keyCode(escapeKey) = true;
            end
        elseif strcmpi(currentState,'feedback')
            if firstStateEntrance
                firstStateEntranceTime = timeNow;
                firstStateEntrance = false;
                t_feedback.leave = audio_T;
                
                leaveState = false;
                draw.Allow = false;
                reset_state_shock = false;
                %update the state based on the choice
                if not(data.result(ix_trial).bound == 0)
                    reset_state_shock = true;
                end
                wavedata_shock = randn(audio_channels, length(audio_t));
                PsychPortAudio('FillBuffer', pahandle, wavedata_shock);
            end
            t_state_now = timeNow - firstStateEntranceTime;
            
            if (t_state_now > 0)&&reset_state_shock
                PsychPortAudio('Start',pahandle);
                reset_state_shock = false;
                lower_bound_inst = data.protocol.lower_bound;
                upper_bound_inst = data.protocol.upper_bound;
                x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
                disp([lower_bound_inst, x, upper_bound_inst]);
            elseif t_state_now > t_feedback.leave
                leaveState = true;
            end
            
            if leaveState
                currentState = 'fixate';
                firstStateEntrance = true;
                choice = round(2*(randi(2)-1.5));
                PsychPortAudio('Stop', pahandle, 1);
            elseif timeNow>data.protocol.maxtime
                keyCode(escapeKey) = true;
            end
            
        elseif strcmpi(currentState,'choice')
            if firstStateEntrance
                firstStateEntranceTime = timeNow;
                firstStateEntrance = false;
                t_feedback.leave = data.protocol.rt_max;
                
                leaveState_choice = false;
                leaveState_fb = false;
                
                draw.Allow = true;
                listen_for_response = true;
                choice = round(2*(randi(2)-1.5));
            end
            draw.Allow = true;
            drawCross(w, data.protocol.crossL, data.protocol.crossW, 0, [0,1,0]);
            t_state_now = timeNow - firstStateEntranceTime;
            
            
            if keyIsDown&&listen_for_response
                % the RT is associated with previous trialTime so -1
                data.result(ix_trial).rt_choice = timeNow-firstStateEntranceTime;
                if logical(keyCode(upKey))
                    choice = +1;
                    listen_for_response = false;
                    data.result(ix_trial).choice = choice;
                    leaveState_fb = true;
                elseif logical(keyCode(doKey))
                    choice = -1;
                    listen_for_response = false;
                    data.result(ix_trial).choice = choice;
                    leaveState_fb = true;
                end
            elseif t_state_now > t_feedback.leave
                leaveState_choice = true;
            end
            
            
            if leaveState_fb
                currentState = 'feedback';
                firstStateEntrance = true;
            elseif leaveState_choice
                currentState = 'fixate';
                firstStateEntrance = true;
            elseif timeNow>data.protocol.maxtime
                keyCode(escapeKey) = true;
            end
            
            
            
        end
        
        %% Screen update
        if draw.Allow
            vbl = Screen('Flip', w);
            draw.Allow = false;
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
PsychPortAudio('Close');

if errorHappened
    psychrethrow(psychlasterror);
end
% ab_basic;
end

function drawCross(window, W, L, theta, c)
rect_array = ones(L, W, 3).*reshape(c,[1,1,3])*255;
t1=Screen('MakeTexture',window,rect_array);
t2=Screen('MakeTexture',window,rect_array);
Screen('DrawTexture',window,t1,[],[],theta);
Screen('DrawTexture',window,t2,[],[],theta+90);
end