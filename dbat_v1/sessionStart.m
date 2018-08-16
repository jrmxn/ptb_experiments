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
d.lower_bound_step = +25;
d.lower_bound_step_alt = 0;
d.lower_bound_step_prob = 0.5;
d.upper_bound_step = -0;
d.upper_bound_step_alt = 0;
d.upper_bound_step_prob = 0.5;
d.state_gain = abs(2*d.lower_bound_step);
d.state_noise = 10;
d.rt_max = 1.8;
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
%%
audioFs = 96e3;
audio_T = 0.15;
audio_t = 0:1/audioFs:audio_T;
audio_channels = 2;

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
    upper_bound_inst = data.protocol.upper_bound;
    lower_bound_inst = data.protocol.lower_bound;
    x = lower_bound_inst + (upper_bound_inst - lower_bound_inst)/2;
    
    rng(0)
    audio_buffer_time = 0.1;
    
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
                draw.Allow = true;
                drawCross(w, data.protocol.crossL, data.protocol.crossW, 0);
                
                
                t_fixate.buffer = audio_buffer_time;
                t_fixate.leave = data.protocol.rt_max;
                
                enable_stimulus = true;
                listen_for_response = true;
                leaveState = false;
                
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
                x_obs = x + randn*data.protocol.state_noise;
                
                data.result(ix_trial).x = x;
                data.result(ix_trial).x_obs = x_obs;
                data.result(ix_trial).rt = nan;
                data.result(ix_trial).upper_bound_inst = upper_bound_inst;
                data.result(ix_trial).lower_bound_inst = lower_bound_inst;
                data.result(ix_trial).choice = -1;
                
%                 wavedata1 = repmat(sin(2*pi*lower_bound_inst*audio_t),audio_channels,1);
%                 wavedata2 = repmat(wavedata1,1,2)*0;
%                 wavedata3 = repmat(sin(2*pi*upper_bound_inst*audio_t),audio_channels,1);
%                 wavedata4 = repmat(wavedata1,1,4)*0;
%                 wavedata5 = repmat(sin(2*pi*x_obs*audio_t),audio_channels,1);
%                 wavedata = [wavedata1,wavedata2,wavedata3,wavedata4,wavedata5];
                
%                 wavedata1 = repmat(sin(2*pi*upper_bound_inst*audio_t),audio_channels,1);
%                 wavedata2 = repmat(wavedata1,1,4)*0;
%                 wavedata3 = repmat(sin(2*pi*x_obs*audio_t),audio_channels,1);
%                 wavedata = [wavedata1,wavedata2,wavedata3];
%                 y = sin(2*pi*lower_bound_inst*[1/audioFs:1/audioFs:length(wavedata)/audioFs]);
%                 wavedata(1,:) = y;

                wavedata1 = repmat(sin(2*pi*upper_bound_inst*audio_t),audio_channels,1);
                wavedata1(1,:) = sin(2*pi*lower_bound_inst*audio_t);
                wavedata2 = repmat(wavedata1,1,3)*0;
                wavedata3 = repmat(sin(2*pi*x_obs*audio_t),audio_channels,1);
                wavedata = [wavedata1,wavedata2,wavedata3];
                
                PsychPortAudio('FillBuffer',pahandle,wavedata);
                
            end
            t_state_now = timeNow - firstStateEntranceTime;
            
            
            if (t_state_now>t_fixate.buffer)&&enable_stimulus
                PsychPortAudio('Start',pahandle, 1, 0, 0);
                enable_stimulus = false;
            elseif t_state_now>t_fixate.leave
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
                    data.result(ix_trial).choice = 0;
                    %should punish here
                end
                listen_for_response = false;
                %optional:
                %                     leaveState = true;
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
                
                t_feedback.buffer = audio_buffer_time;
                t_feedback.leave = t_feedback.buffer + audio_T;
                
                leaveState = false;
                draw.Allow = false;
                reset_state_shock = false;
                %update the state based on the choice
                x = x + data.protocol.state_gain*data.result(ix_trial).choice;
                if x > upper_bound_inst
                    %shock!
                    reset_state_shock = true;
                elseif x < lower_bound_inst
                    %shock!
                    reset_state_shock = true;
                end
                wavedata_shock = randn(audio_channels, length(audio_t));
                PsychPortAudio('FillBuffer',pahandle,[wavedata_shock]);
            end
            t_state_now = timeNow - firstStateEntranceTime;
            
            if (t_state_now > t_feedback.buffer)&&reset_state_shock
                PsychPortAudio('Start',pahandle, 1, 0, 0);
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