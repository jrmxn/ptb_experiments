function sessionStart(varargin)
%% 
%
d.maxtime = Inf;
d.t_rot = 0.02;%time to rotate
d.deg_max = 45;
d.debugMode = false;
d.useMouseClicks = false;
d.lower_fixate = 35;
d.upper_fixate = 45;
d.lower_fixate = 5;
d.upper_fixate = 6;
d.crossL = 16;%unit: pixels. Should be 6 degrees. Needs calculating depdent on physical monitor size and resolution.
d.crossW = d.crossL/8;
d.saveDir = fullfile(pwd,'data');
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
                draw.Allow = true;
                trialTime = pd_fixate.random;%draw this from dist
                listen_for_response = true;
                leaveState = false;
                ix_trial = ix_trial + 1;
                data.result(ix_trial).rt = nan;
                data.result(ix_trial).trialTime = trialTime;
            else
                draw.Allow = false;
                if (timeNow - firstStateEntranceTime)>trialTime
                    leaveState = true;
                end
                
                if keyIsDown&&listen_for_response&&(ix_trial>1)
                    % the RT is associated with previous trialTime so -1
                    data.result(ix_trial-1).rt = timeNow-firstStateEntranceTime;
                    listen_for_response = false;
                end
            end
            
            if leaveState
                currentState = 'rotate';
                firstStateEntrance = true;
                if timeNow>data.protocol.maxtime
                    keyCode(escapeKey) = true;
                end
            end
        elseif strcmpi(currentState,'rotate')
            if firstStateEntrance
                firstStateEntranceTime = timeNow;
                firstStateEntrance = false;
                leaveState = false;
                draw.Allow = true;
            end
            
            t_now = timeNow - firstStateEntranceTime;
            %             t_rot_norm = t_rot/data.protocol.t_rot_max;
            %             deg_rot = t_rot_norm*data.protocol.deg_max;
            %seems like roation is instant in paper
            if t_now < data.protocol.t_rot
                deg_rot = data.protocol.deg_max;
            else
                leaveState = true;
            end
            drawCross(w, data.protocol.crossL, data.protocol.crossW, deg_rot);%make it rotate
            
            if leaveState
                currentState = 'fixate';
                firstStateEntrance = true;
            end
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