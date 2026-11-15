function figOut = PoleDragLab
%POLEDRAGLAB  Drag the poles of a 2nd-order system and watch the response.
%
%   KON314 Control System Design
%
%   G(s) = wn^2 / (s^2 + 2*zeta*wn*s + wn^2),   poles  p = sigma +/- j*wd
%
%   1. Click or drag in the s-plane to move the complex pole pair.
%   2. The mass-spring-damper (m = 1, c = 2*zeta*wn, k = wn^2) moves with
%      the step response, and %OS, Tp, Ts, Tr are measured live.
%   3. Use "Drag mode" to move the pole along a line of constant
%      sigma (same Ts), wd (same Tp), zeta (same %OS) or wn.
%   4. Press Play to watch the mass start from rest (y = 0) and the step
%      response being drawn in time.
%   5. "Keep curve" freezes the current response in grey for comparison.
%
%   Plain MATLAB (R2024b or newer), no toolboxes needed.

%% ---------------- Settings ----------------
T  = 12;                    % simulated time [s]
dt = 0.01;
t  = (0:dt:T)';
S.a = -0.8;  S.b = 2.0;     % pole: sigma (a) and wd (b)
S.p0 = [S.a S.b];           % pole when the drag started
S.dragging = false;
S.busy = false;             % a drag update is being drawn
S.pending = false;          % a newer mouse position is waiting
S.cp = [0 0];               % latest mouse position
S.speed = 1;
S.playing = false;          % animation running?
S.tc = 0;                   % current animation time [s]
S.tStart = 0;               % animation time when Play was pressed
Y = zeros(size(t));
kept = gobjects(0);

cTs = [0.90 0.45 0.00];     % orange : settling time  <->  sigma
cTp = [0.55 0.20 0.75];     % purple : peak time      <->  wd
cOS = [0.00 0.60 0.25];     % green  : overshoot      <->  zeta
cWn = [0.45 0.45 0.45];     % grey   : natural freq.  <->  |p|
cY  = [0.00 0.35 0.85];

%% ---------------- Window ----------------
ss  = get(groot,'ScreenSize');
fig = uifigure('Name','Pole Drag Lab — 2nd-order system', ...
    'Position',[40 max(40, ss(4)-880) 1380 min(820, ss(4)-80)]);
g = uigridlayout(fig,[2 3],'ColumnWidth',{'1x','1.25x',340},'RowHeight',{'0.8x','1x'});

% ---- s-plane ----
axS = uiaxes(g);  axS.Layout.Row = [1 2];  axS.Layout.Column = 1;
hold(axS,'on'); box(axS,'on'); grid(axS,'on');
disableDefaultInteractivity(axS);  axS.Toolbar.Visible = 'off';
xl = [-6 2];  yl = [-5 5];
patch(axS,[0 xl(2) xl(2) 0],[yl(1) yl(1) yl(2) yl(2)],[1 0.85 0.85], ...
    'EdgeColor','none','HitTest','off');
text(axS,1,4.5,{'UNSTABLE','region'},'Color',[0.75 0 0],'FontWeight','bold', ...
    'HorizontalAlignment','center','HitTest','off');
plot(axS,xl,[0 0],'k','HitTest','off');  plot(axS,[0 0],yl,'k','HitTest','off');
hSig = plot(axS,[0 0],yl,'--','Color',cTs,'LineWidth',1.3,'HitTest','off');
hWdU = plot(axS,xl,[0 0],'--','Color',cTp,'LineWidth',1.3,'HitTest','off');
hWdL = plot(axS,xl,[0 0],'--','Color',cTp,'LineWidth',1.3,'HitTest','off');
hZet = plot(axS,[0 0],[0 0],'-','Color',cOS,'LineWidth',1.3,'HitTest','off');
hWn  = plot(axS,0,0,':','Color',cWn,'LineWidth',1.3,'HitTest','off');
hP   = plot(axS,[0 0],[0 0],'x','Color',cY,'MarkerSize',18,'LineWidth',3.5,'HitTest','off');
hPt  = text(axS,0,0,'','FontSize',11,'FontWeight','bold','HitTest','off');
xlabel(axS,'Real axis  \sigma');  ylabel(axS,'Imaginary axis  j\omega');
title(axS,'s-plane — click or drag the pole');
axS.XLim = xl;  axS.YLim = yl;  axS.DataAspectRatio = [1 1 1];

% ---- mass-spring-damper ----
axM = uiaxes(g);  axM.Layout.Row = 1;  axM.Layout.Column = 2;
hold(axM,'on');  axis(axM,'off');
disableDefaultInteractivity(axM);  axM.Toolbar.Visible = 'off';
axM.XLim = [-0.4 7.6];  axM.YLim = [-0.9 0.9];  axM.DataAspectRatio = [1 1 1];
patch(axM,[-0.3 0 0 -0.3],[-0.7 -0.7 0.7 0.7],[0.6 0.6 0.6],'EdgeColor','k');
plot(axM,[0 7.6],[-0.52 -0.52],'k','LineWidth',1);
plot(axM,[3.8 3.8],[-0.75 0.75],':k');          % mass centre at y = 0
plot(axM,[4.7 4.7],[-0.75 0.75],'--','Color',cOS); % mass centre at y = 1
text(axM,3.8,-0.78,'y = 0','HorizontalAlignment','center','FontSize',10);
text(axM,4.7,-0.78,'y = 1 (target)','HorizontalAlignment','left','Color',cOS,'FontSize',10);
hSpr  = plot(axM,0,0,'Color',[0 0.3 0.8],'LineWidth',2);
plot(axM,[0 0.4],[-0.25 -0.25],'k','LineWidth',2);
hCyl  = plot(axM,[3.1 0.4 0.4 3.1],[-0.13 -0.13 -0.37 -0.37],'k','LineWidth',2);
hRod  = plot(axM,0,0,'k','LineWidth',2);
hMass = patch(axM,0,0,[0.85 0.88 0.95],'EdgeColor','k','LineWidth',1.5);
hMtx  = text(axM,0,0,'m','HorizontalAlignment','center','FontSize',14,'FontWeight','bold');
hArr  = plot(axM,0,0,'Color',[0.8 0 0],'LineWidth',2);
hHead = patch(axM,0,0,[0.8 0 0],'EdgeColor','none');
hFtx  = text(axM,0,0.2,'F','Color',[0.8 0 0],'FontWeight','bold');
title(axM,'');

% ---- step response ----
axY = uiaxes(g);  axY.Layout.Row = 2;  axY.Layout.Column = 2;
hold(axY,'on'); grid(axY,'on'); box(axY,'on');
disableDefaultInteractivity(axY);  axY.Toolbar.Visible = 'off';
hBand = patch(axY,[0 T T 0],[0.98 0.98 1.02 1.02],cTs,'FaceAlpha',0.15,'EdgeColor','none', ...
    'DisplayName','±2% band');
hRef = plot(axY,[0 T],[1 1],'k--','DisplayName','Reference r = 1');
hYf  = plot(axY,t,Y,'Color',[cY 0.25],'LineWidth',1.5,'HandleVisibility','off');
hY   = plot(axY,t,Y,'Color',cY,'LineWidth',2.2,'DisplayName','Step response y(t)');
hTp  = plot(axY,[0 0],[-1 3],'--','Color',cTp,'LineWidth',1.2,'DisplayName','T_p');
hTs  = plot(axY,[0 0],[-1 3],'--','Color',cTs,'LineWidth',1.2,'DisplayName','T_s');
hPk  = plot(axY,0,0,'o','MarkerFaceColor',cOS,'MarkerEdgeColor','k','MarkerSize',8, ...
    'DisplayName','Peak (%OS)');
hCur = plot(axY,0,0,'o','MarkerFaceColor',[0.8 0 0],'MarkerEdgeColor','none', ...
    'MarkerSize',9,'HandleVisibility','off');
xlabel(axY,'Time [s]');  ylabel(axY,'Output y');  title(axY,'Unit step response');
axY.XLim = [0 T];  axY.YLim = [-0.3 2.2];
legend(axY,[hBand hRef hY hTp hTs hPk],'Location','northeast');   % fixed list: kept curves never reorder it

%% ---------------- Side panel ----------------
side = uigridlayout(g,[16 3],'RowHeight',{22,44,22,30,30,8,22,22,22,22,22,22,22,22,56,'1x'}, ...
    'ColumnWidth',{120,70,'1x'},'RowSpacing',5);
side.Layout.Row = [1 2];  side.Layout.Column = 3;

L = uilabel(side,'Text','Transfer function','FontWeight','bold');  L.Layout.Column = [1 3];
lblG = uilabel(side,'Interpreter','latex','FontSize',17,'HorizontalAlignment','center');
lblG.Layout.Column = [1 3];
lblM = uilabel(side,'FontSize',12,'HorizontalAlignment','center');
lblM.Layout.Column = [1 3];

uilabel(side,'Text','Drag mode','FontWeight','bold');
ddMode = uidropdown(side,'Items',{'Free', ...
    'Keep σ  (same Ts)','Keep ωd  (same Tp)','Keep ζ  (same %OS)','Keep ωn'}, ...
    'ValueChangedFcn',@(~,~) []);
ddMode.Layout.Column = [2 3];

uilabel(side,'Text','Examples','FontWeight','bold');
ex = {'Choose…', 'ζ = 0.2  (big overshoot)', 'ζ = 0.7  (classic design)', ...
      'ζ = 1  (critically damped)', 'ζ = 0  (no damping)', 'σ > 0  (unstable)'};
ddEx = uidropdown(side,'Items',ex,'ValueChangedFcn',@onExample);
ddEx.Layout.Column = [2 3];

uilabel(side,'Text','');  % spacer
uilabel(side,'Text','');  uilabel(side,'Text','');

rows = { ...
    'ζ   damping ratio',  'cos θ',              cOS
    'ωn  natural freq.',  '|p|  (distance)',    cWn
    'σ   real part',      '= −ζ ωn',            cTs
    'ωd  imag. part',     '= ωn √(1−ζ²)',       cTp
    '%OS overshoot',      '100·e^(−ζπ/√(1−ζ²))', cOS
    'Tp  peak time',      '= π / ωd',           cTp
    'Ts  settling (2%)',  '≈ 4 / |σ|',          cTs
    'Tr  rise (10–90%)',  'measured',           [0 0 0]};
val = gobjects(size(rows,1),1);
for i = 1:size(rows,1)
    uilabel(side,'Text',rows{i,1},'FontWeight','bold','FontColor',rows{i,3});
    val(i) = uilabel(side,'Text','','FontName','Menlo','HorizontalAlignment','right');
    uilabel(side,'Text',rows{i,2},'FontColor',[0.35 0.35 0.35]);
end

lblStat = uilabel(side,'WordWrap','on','FontWeight','bold','FontSize',13);
lblStat.Layout.Column = [1 3];

low = uigridlayout(side,[4 2],'RowHeight',{36,30,30,'1x'},'Padding',[0 0 0 0]);
low.Layout.Column = [1 3];
btnPlay  = uibutton(low,'Text','▶  Play','FontWeight','bold','FontSize',14, ...
    'BackgroundColor',[0.80 0.93 0.80],'ButtonPushedFcn',@(~,~) play());
btnPause = uibutton(low,'Text','⏸  Pause','FontSize',14,'Enable','off', ...
    'ButtonPushedFcn',@(~,~) pauseResume());
uibutton(low,'Text','Keep curve','ButtonPushedFcn',@onKeep);
uibutton(low,'Text','Clear kept','ButtonPushedFcn',@onClear);
uidropdown(low,'Items',{'Speed 0.25×','Speed 0.5×','Speed 1×','Speed 2×'},'Value','Speed 1×', ...
    'ValueChangedFcn',@(s,~) setSpeed(s.Value));
cbLoop = uicheckbox(low,'Text','Loop','Value',false);
hint = uilabel(low,'WordWrap','on','VerticalAlignment','top','FontColor',[0.25 0.25 0.25],'Text', ...
    ['Read the s-plane:' newline ...
     '•  Further LEFT  →  decays faster  (smaller Ts)' newline ...
     '•  HIGHER  →  oscillates faster  (smaller Tp)' newline ...
     '•  Closer to the jω axis  →  smaller ζ, more overshoot' newline ...
     '•  RIGHT half-plane  →  unstable' newline newline ...
     'Mass–spring–damper:  m·ÿ + c·ẏ + k·y = k·u' newline ...
     'with  m = 1,  c = 2ζωn = −2σ,  k = ωn² = |p|²']);
hint.Layout.Row = 4;  hint.Layout.Column = [1 2];

%% ---------------- Interaction & animation ----------------
fig.WindowButtonDownFcn   = @onDown;
fig.WindowButtonMotionFcn = @onMove;
fig.WindowButtonUpFcn     = @onUp;

t0  = tic;
lastErr = '';
tmr = timer('ExecutionMode','fixedSpacing','Period',0.03,'BusyMode','drop', ...
    'TimerFcn',@(~,~) tick());
fig.CloseRequestFcn = @(~,~) closeApp();

update();
play();
if nargout > 0, figOut = fig; end

%% ================= Nested functions =================
    function update()
        a = S.a;  b = S.b;
        wn = hypot(a,b);  zeta = -a/wn;

        % analytic step response of wn^2/((s-a)^2 + b^2)
        if b > 0
            Y = 1 - exp(a*t).*(cos(b*t) - (a/b)*sin(b*t));
        else
            Y = 1 - exp(a*t).*(1 - a*t);
        end

        % s-plane
        hP.XData = [a a];  hP.YData = [b -b];
        hPt.Position = [a+0.25 b+0.35 0];
        hPt.String = sprintf('ζ = %.2f', zeta);
        hSig.XData = [a a];
        hWdU.YData = [b b];  hWdL.YData = [-b -b];
        r = 8;  hZet.XData = [r*a/wn 0 r*a/wn];  hZet.YData = [r*b/wn 0 -r*b/wn];
        th = linspace(0,2*pi,200);  hWn.XData = wn*cos(th);  hWn.YData = wn*sin(th);

        % transfer function & mechanical parameters
        % (the LaTeX label is slow to render, so it waits until the mouse is released)
        if ~S.dragging
            c = -2*a;  k = wn^2;
            if c >= 0, sg = '+'; else, sg = '-'; end
            if abs(c) < 1e-9
                setText(lblG, sprintf('$G(s)=\\frac{%.2f}{s^2+%.2f}$', k, k));
            else
                setText(lblG, sprintf('$G(s)=\\frac{%.2f}{s^2%s%.2fs+%.2f}$', k, sg, abs(c), k));
            end
            setText(lblM, sprintf('m = 1,   c = %.2f,   k = %.2f', c, k));
        end

        % metrics
        setText(val(1), sprintf('%.3f', zeta));
        setText(val(2), sprintf('%.2f', wn));
        setText(val(3), sprintf('%.2f', a));
        setText(val(4), sprintf('%.2f', b));
        [os, tp, ts, tr] = metrics();
        setText(val(5), fmt(os, '%.1f %%'));
        setText(val(6), fmt(tp, '%.2f s'));
        setText(val(7), fmt(ts, '%.2f s'));
        setText(val(8), fmt(tr, '%.2f s'));

        % step plot
        hYf.YData = Y;
        if ~S.dragging, showTime(S.tc); end    % while dragging the mass stays at rest
        if isfinite(tp)
            [~,ip] = max(Y);
            hPk.XData = t(ip);  hPk.YData = Y(ip);  hPk.Visible = 'on';
            hTp.XData = [tp tp];  hTp.Visible = 'on';
        else
            hPk.Visible = 'off';  hTp.Visible = 'off';
        end
        if isfinite(ts), hTs.XData = [ts ts];  hTs.Visible = 'on';
        else,            hTs.Visible = 'off';
        end

        % status
        if a > 0
            msg = 'UNSTABLE (σ > 0): the response grows without bound. The damper pushes instead of braking (c < 0).';
            col = [0.8 0 0];
        elseif a == 0
            msg = 'MARGINALLY STABLE (ζ = 0): no damping, it oscillates forever.';
            col = [0.85 0.45 0];
        elseif b == 0
            msg = 'CRITICALLY DAMPED (ζ = 1): double real pole, no overshoot.';
            col = cOS;
        else
            msg = 'UNDERDAMPED (0 < ζ < 1): it overshoots, oscillates, then settles.';
            col = cY;
        end
        if ~strcmp(lblStat.Text, msg), lblStat.Text = msg;  lblStat.FontColor = col; end
    end

    function setText(h, str)
        % write to a label only when the text really changes (each write is a round trip)
        if ~strcmp(h.Text, str), h.Text = str; end
    end

    function [os, tp, ts, tr] = metrics()
        os = NaN; tp = NaN; ts = NaN; tr = NaN;
        if S.a >= 0, return; end
        [ym, ip] = max(Y);
        os = max(0, 100*(ym - 1));
        if os > 0.05 && ip < numel(t), tp = t(ip); else, os = 0; end
        iOut = find(abs(Y - 1) > 0.02, 1, 'last');
        if isempty(iOut), ts = 0; elseif iOut < numel(t), ts = t(iOut+1); else, ts = Inf; end
        i10 = find(Y >= 0.1, 1);  i90 = find(Y >= 0.9, 1);
        if ~isempty(i10) && ~isempty(i90), tr = t(i90) - t(i10); end
    end

    function s = fmt(v, f)
        if isnan(v), s = '—';
        elseif isinf(v), s = sprintf('> %g s', T);
        else, s = sprintf(f, v);
        end
    end

    function tick()
        try
            if ~isvalid(fig) || ~S.playing, return; end
            tc = S.tStart + toc(t0)*S.speed;
            if tc >= T
                if cbLoop.Value
                    S.tStart = 0;  t0 = tic;  tc = 0;
                else
                    tc = T;  stopPlay();
                end
            end
            showTime(tc);
            drawnow limitrate
        catch err
            if ~strcmp(err.message, lastErr)       % report each error once
                lastErr = err.message;
                fprintf(2, 'PoleDragLab animation: %s\n', err.message);
            end
        end
    end

    function showTime(tc)
        % draw the mass, the time cursor and the response up to time tc
        S.tc = tc;
        k = round(tc/dt) + 1;
        drawMass(Y(k));
        set(hY, 'XData', t(1:k), 'YData', Y(1:k));
        hCur.XData = t(k);  hCur.YData = min(max(Y(k), axY.YLim(1)), axY.YLim(2));
        axM.Title.String = sprintf('Mass–spring–damper     t = %.1f s     y = %.2f', tc, Y(k));
    end

    function play()
        % start the animation from rest: t = 0, y = 0
        S.tStart = 0;  t0 = tic;  S.playing = true;
        btnPause.Enable = 'on';  btnPause.Text = '⏸  Pause';
        showTime(0);
        timerOn();
    end

    function pauseResume()
        if S.playing
            S.playing = false;  btnPause.Text = '▶  Resume';
            timerOff();
        else
            S.tStart = S.tc;  t0 = tic;  S.playing = true;
            btnPause.Text = '⏸  Pause';
            timerOn();
        end
    end

    function stopPlay()
        S.playing = false;
        btnPause.Enable = 'off';  btnPause.Text = '⏸  Pause';
        timerOff();
    end

    function timerOn()
        % the timer only runs during playback, so it never competes with dragging
        if isvalid(tmr) && strcmp(tmr.Running, 'off'), start(tmr); end
    end

    function timerOff()
        if isvalid(tmr) && strcmp(tmr.Running, 'on'), stop(tmr); end
    end

    function drawMass(y)
        yc = min(max(y, -0.5), 2.2);
        xm = 3.2 + 0.9*yc;                         % left face of the mass
        [sx, sy] = spring(0, xm, 0.25);
        hSpr.XData = sx;  hSpr.YData = sy;
        xp = xm - 2.2;                             % piston plate
        hRod.XData = [xm xp NaN xp xp];  hRod.YData = [-0.25 -0.25 NaN -0.35 -0.15];
        if S.a > 0, hCyl.Color = [0.8 0 0]; else, hCyl.Color = [0 0 0]; end
        hMass.XData = [xm xm+1.2 xm+1.2 xm];  hMass.YData = [-0.5 -0.5 0.5 0.5];
        hMtx.Position = [xm+0.6 0 0];
        hArr.XData = [xm+1.2 xm+1.85];  hArr.YData = [0 0];
        hHead.XData = [xm+1.85 xm+1.85 xm+2.1];  hHead.YData = [-0.1 0.1 0];
        hFtx.Position = [xm+1.5 0.2 0];
    end

    function onDown(~,~)
        cp = axS.CurrentPoint(1,1:2);
        if cp(1) < xl(1) || cp(1) > xl(2) || cp(2) < yl(1) || cp(2) > yl(2), return; end
        S.dragging = true;
        S.p0 = [S.a S.b];
        stopPlay();  showTime(0);                  % back to rest; press Play to run
        movePole(cp);
    end

    function onMove(~,~)
        if ~S.dragging, return; end
        S.cp = axS.CurrentPoint(1,1:2);
        S.pending = true;
        if S.busy, return; end           % still drawing: only keep the latest position
        S.busy = true;
        while S.pending                  % draw the newest position, skip the ones in between
            S.pending = false;
            movePole(S.cp);
            drawnow limitrate
        end
        S.busy = false;
    end

    function onUp(~,~)
        if ~S.dragging, return; end
        S.dragging = false;
        S.busy = false;  S.pending = false;
        update();                        % full update, including the LaTeX label
    end

    function movePole(cp)
        x = min(max(cp(1), xl(1)), xl(2));
        y = min(abs(cp(2)), yl(2));
        a0 = S.p0(1);  b0 = S.p0(2);
        switch ddMode.Value
            case 'Keep σ  (same Ts)',   x = a0;
            case 'Keep ωd  (same Tp)',  y = b0;
            case 'Keep ζ  (same %OS)'
                d = [a0 b0]/hypot(a0,b0);
                rr = max(dot([x y], d), 0.2);
                x = rr*d(1);  y = rr*d(2);
            case 'Keep ωn'
                rr = hypot(a0,b0);  n = hypot(x,y);
                if n < 1e-6, return; end
                x = rr*x/n;  y = rr*y/n;
        end
        if abs(x) < 0.08, x = 0; end               % snap to the jω axis
        if y < 0.08, y = 0; end                    % snap to the real axis
        if hypot(x,y) < 0.2                        % keep away from the origin
            if hypot(x,y) < 1e-6, x = -0.2; y = 0;
            else, sc = 0.2/hypot(x,y); x = x*sc; y = y*sc; end
        end
        S.a = x;  S.b = y;
        update();
    end

    function onExample(src,~)
        wn = 2.5;
        switch find(strcmp(src.Items, src.Value))
            case 2, z = 0.2;
            case 3, z = 0.7;
            case 4, z = 1;
            case 5, z = 0;
            case 6, S.a = 0.3;  S.b = 2;  z = [];
            otherwise, return
        end
        if ~isempty(z), S.a = -z*wn;  S.b = wn*sqrt(max(0, 1 - z^2)); end
        src.Value = src.Items{1};
        stopPlay();  S.tc = 0;
        update();
    end

    function onKeep(~,~)
        kept(end+1) = plot(axY, t, Y, 'Color',[0.6 0.6 0.6], 'LineWidth',1.2, ...
            'HandleVisibility','off');
        kept(end+1) = plot(axS, [S.a S.a], [S.b -S.b], 'x', 'Color',[0.6 0.6 0.6], ...
            'MarkerSize',12, 'LineWidth',2, 'HitTest','off');
        uistack(hY,'top');  uistack(hP,'top');
    end

    function onClear(~,~)
        delete(kept(isvalid(kept)));  kept = gobjects(0);
    end

    function setSpeed(v)
        S.tStart = S.tc;  t0 = tic;                % keep the current time
        S.speed = sscanf(v, 'Speed %f');
    end

    function closeApp()
        try stop(tmr); delete(tmr); catch, end
        delete(fig);
    end
end

function [x, y] = spring(x1, x2, y0)
% Zig-zag spring between x1 and x2 at height y0.
n  = 8;  lead = 0.25;
xs = linspace(x1 + lead, x2 - lead, 2*n + 1);
ys = y0*ones(size(xs));
ys(2:2:end-1) = y0 + 0.12;
ys(3:2:end-1) = y0 - 0.12;
x = [x1 xs x2];  y = [y0 ys y0];
end
