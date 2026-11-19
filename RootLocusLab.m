function figOut = RootLocusLab
%ROOTLOCUSLAB  Change the gain K and watch the closed-loop poles move.
%
%   KON314 Control System Design
%
%   Unity feedback:   r --> (+) --> K --> G(s) --> y
%                        - ^                    |
%                          '--------------------'
%
%   Closed-loop poles are the roots of   1 + K*G(s) = 0.
%   As K goes from 0 to infinity they trace the ROOT LOCUS.
%
%   1. Move the K slider, or click / drag along the locus in the s-plane.
%   2. "Sweep K" animates K from 0 to Kmax.
%   3. Examples: add a pole or a zero and see how the locus bends.
%   4. "K = Kcr" jumps to the stability limit (if there is one).
%   5. "Keep curve" freezes the current response in grey for comparison.
%
%   Plain MATLAB (R2024b or newer), no toolboxes needed.

%% ---------------- Settings ----------------
T  = 15;                    % simulated time [s]
dt = 0.01;
t  = (0:dt:T)';

E = struct( ...
    'item', {'G = 1/(s(s+1))', ...
             'G = 1/(s(s+1)(s+3))   — add a pole', ...
             'G = (s+2)/(s(s+1))   — add a zero', ...
             'G = (s+2)/(s(s+1)(s+3))   — pole + zero'}, ...
    'num',  {1, 1, [1 2], [1 2]}, ...
    'den',  {[1 1 0], [1 4 3 0], [1 1 0], [1 4 3 0]}, ...
    'Kmax', {10, 30, 20, 30}, ...
    'texG', {'$G(s)=\frac{1}{s(s+1)}$', '$G(s)=\frac{1}{s(s+1)(s+3)}$', ...
             '$G(s)=\frac{s+2}{s(s+1)}$', '$G(s)=\frac{s+2}{s(s+1)(s+3)}$'}, ...
    'texC', {'$s(s+1)+K=0$', '$s(s+1)(s+3)+K=0$', ...
             '$s(s+1)+K(s+2)=0$', '$s(s+1)(s+3)+K(s+2)=0$'});

S.e = 2;                    % current example
S.K = 0;                    % current gain
S.Kcr = Inf;                % stability limit of the current example
S.Kg = [];  S.R = [];       % gain grid and locus points (one row per branch)
S.dragging = false;
S.busy = false;  S.pending = false;  S.cp = [0 0];
S.playing = false;  S.Kstart = 0;
Y = zeros(size(t));
kept = gobjects(0);

cY  = [0.00 0.35 0.85];     % blue  : closed-loop poles, response
cL  = [0.00 0.55 0.55];     % teal  : root locus
cR  = [0.80 0.00 0.00];     % red   : stability limit

%% ---------------- Window ----------------
ss  = get(groot,'ScreenSize');
fig = uifigure('Name','Root Locus Lab — closed-loop poles vs. gain K', ...
    'Position',[40 max(40, ss(4)-880) 1380 min(820, ss(4)-80)]);
g = uigridlayout(fig,[2 3],'ColumnWidth',{'1.1x','1x',330},'RowHeight',{'1x',96});

% ---- s-plane ----
axS = uiaxes(g);  axS.Layout.Row = 1;  axS.Layout.Column = 1;
hold(axS,'on'); box(axS,'on'); grid(axS,'on');
disableDefaultInteractivity(axS);  axS.Toolbar.Visible = 'off';
xl = [-6 2];  yl = [-4 4];
patch(axS,[0 xl(2) xl(2) 0],[yl(1) yl(1) yl(2) yl(2)],[1 0.85 0.85], ...
    'EdgeColor','none','HitTest','off','HandleVisibility','off');
text(axS,1,3.5,{'UNSTABLE','region'},'Color',cR,'FontWeight','bold', ...
    'HorizontalAlignment','center','HitTest','off');
plot(axS,xl,[0 0],'k','HitTest','off','HandleVisibility','off');
plot(axS,[0 0],yl,'k','HitTest','off','HandleVisibility','off');
hLoc = plot(axS,NaN,NaN,'-','Color',cL,'LineWidth',2.2,'HitTest','off','DisplayName','Root locus');
hOL  = plot(axS,NaN,NaN,'kx','MarkerSize',13,'LineWidth',2.5,'HitTest','off','DisplayName','Open-loop poles (K = 0)');
hZ   = plot(axS,NaN,NaN,'ko','MarkerSize',11,'LineWidth',2.5,'HitTest','off','DisplayName','Zeros (K → ∞)');
hKc  = plot(axS,NaN,NaN,'d','MarkerFaceColor',cR,'MarkerEdgeColor','k','MarkerSize',9, ...
    'HitTest','off','DisplayName','Stability limit K_{cr}');
hKct = text(axS,0,0,'','Color',cR,'FontWeight','bold','HitTest','off');
hCL  = plot(axS,NaN,NaN,'o','MarkerFaceColor',cY,'MarkerEdgeColor','k','MarkerSize',11, ...
    'HitTest','off','DisplayName','Closed-loop poles');
hKt  = text(axS,0,0,'','Color',cY,'FontSize',12,'FontWeight','bold','HitTest','off');
xlabel(axS,'Real axis  \sigma');  ylabel(axS,'Imaginary axis  j\omega');
title(axS,'s-plane — click or drag along the locus');
axS.XLim = xl;  axS.YLim = yl;  axS.DataAspectRatio = [1 1 1];
legend(axS,[hLoc hOL hZ hKc hCL],'Location','southwest');

% ---- step response ----
axY = uiaxes(g);  axY.Layout.Row = 1;  axY.Layout.Column = 2;
hold(axY,'on'); grid(axY,'on'); box(axY,'on');
disableDefaultInteractivity(axY);  axY.Toolbar.Visible = 'off';
hBand = patch(axY,[0 T T 0],[0.98 0.98 1.02 1.02],cL,'FaceAlpha',0.15,'EdgeColor','none', ...
    'DisplayName','±2% band');
hRef = plot(axY,[0 T],[1 1],'k--','DisplayName','Reference r = 1');
hY   = plot(axY,t,Y,'Color',cY,'LineWidth',2.2,'DisplayName','Output y(t)');
xlabel(axY,'Time [s]');  ylabel(axY,'Output y');  title(axY,'Closed-loop step response');
axY.XLim = [0 T];  axY.YLim = [-0.5 2.2];
legend(axY,[hBand hRef hY],'Location','northeast');   % fixed list: kept curves never reorder it

%% ---------------- Gain strip (below the plots) ----------------
strip = uigridlayout(g,[2 1],'RowHeight',{40,32},'Padding',[10 0 10 0],'RowSpacing',6);
strip.Layout.Row = 2;  strip.Layout.Column = [1 2];
r1 = uigridlayout(strip,[1 3],'ColumnWidth',{70,'1x',80},'Padding',[0 0 0 0]);
uilabel(r1,'Text','Gain  K','FontWeight','bold','FontSize',14,'FontColor',cY);
sld = uislider(r1,'Limits',[0 1], ...
    'ValueChangingFcn',@(~,ev) onSlider(ev.Value), ...
    'ValueChangedFcn',@(s,~) onSlider(s.Value));
edK = uieditfield(r1,'numeric','Limits',[0 1],'ValueDisplayFormat','%.2f', ...
    'FontSize',14,'ValueChangedFcn',@(s,~) onSlider(s.Value));

r2 = uigridlayout(strip,[1 6],'ColumnWidth',{'2.4x','1x',60,'1x','1x','1x'},'Padding',[0 0 0 0]);
ddEx = uidropdown(r2,'Items',{E.item},'ValueChangedFcn',@(s,~) setExample(find(strcmp(s.Items, s.Value))));
btnPlay = uibutton(r2,'Text','▶  Sweep K','FontWeight','bold','FontSize',14, ...
    'BackgroundColor',[0.80 0.93 0.80],'ButtonPushedFcn',@(~,~) playPause());
cbLoop = uicheckbox(r2,'Text','Loop','Value',false);
btnKcr = uibutton(r2,'Text','K = Kcr','FontColor',cR,'ButtonPushedFcn',@(~,~) goKcr());
uibutton(r2,'Text','Keep curve','ButtonPushedFcn',@onKeep);
uibutton(r2,'Text','Clear kept','ButtonPushedFcn',@onClear);

%% ---------------- Side panel ----------------
side = uigridlayout(g,[14 2],'RowHeight',{22,48,22,34,8,22,22,22,22,22,22,22,64,'1x'}, ...
    'ColumnWidth',{140,'1x'},'RowSpacing',5);
side.Layout.Row = [1 2];  side.Layout.Column = 3;

L = uilabel(side,'Text','Open-loop plant','FontWeight','bold');  L.Layout.Column = [1 2];
lblG = uilabel(side,'Interpreter','latex','FontSize',17,'HorizontalAlignment','center');
lblG.Layout.Column = [1 2];
L = uilabel(side,'Text','Closed-loop poles:  1 + K·G(s) = 0','FontWeight','bold');
L.Layout.Column = [1 2];
lblC = uilabel(side,'Interpreter','latex','FontSize',15,'HorizontalAlignment','center');
lblC.Layout.Column = [1 2];
L = uilabel(side,'Text','');  L.Layout.Column = [1 2];        % spacer

names = {'K    gain', 'Kcr  stability limit', 'Closed-loop poles', '', ...
         'ζ    dominant pair', '%OS  overshoot', 'Ts   settling (2%)'};
cols  = {cY, cR, cY, cY, [0 0 0], [0 0 0], [0 0 0]};
val = gobjects(numel(names),1);
for i = 1:numel(names)
    if i == 3                                 % "Closed-loop poles": name only, list on the next row
        L = uilabel(side,'Text',names{i},'FontWeight','bold','FontColor',cols{i});
        L.Layout.Column = [1 2];
    elseif i == 4                             % the pole list gets a full row
        val(3) = uilabel(side,'Text','','FontName','Menlo','HorizontalAlignment','right');
        val(3).Layout.Column = [1 2];
    else
        uilabel(side,'Text',names{i},'FontWeight','bold','FontColor',cols{i});
        val(i) = uilabel(side,'Text','','FontName','Menlo','HorizontalAlignment','right');
    end
end

lblStat = uilabel(side,'WordWrap','on','FontWeight','bold','FontSize',13,'VerticalAlignment','top');
lblStat.Layout.Column = [1 2];

hint = uilabel(side,'WordWrap','on','VerticalAlignment','top','FontColor',[0.25 0.25 0.25],'Text', ...
    ['Read the root locus:' newline ...
     '•  K = 0: the poles start on the open-loop poles  ×' newline ...
     '•  K → ∞: they end on the zeros  ○  or run off to infinity' newline ...
     '•  Larger K  →  faster, but more oscillation' newline ...
     '•  Crossing the jω axis  →  unstable  (K > Kcr)' newline ...
     '•  An extra pole bends the locus to the RIGHT' newline ...
     '•  A zero pulls the locus to the LEFT' newline newline ...
     'Unity feedback:   r → ⊕ → K → G(s) → y']);
hint.Layout.Column = [1 2];

%% ---------------- Interaction & animation ----------------
fig.WindowButtonDownFcn   = @onDown;
fig.WindowButtonMotionFcn = @onMove;
fig.WindowButtonUpFcn     = @onUp;

t0  = tic;
lastErr = '';
tmr = timer('ExecutionMode','fixedSpacing','Period',0.03,'BusyMode','drop', ...
    'TimerFcn',@(~,~) tick());
fig.CloseRequestFcn = @(~,~) closeApp();

ddEx.Value = E(S.e).item;
setExample(S.e);
S.K = 0;  update();
playPause();                                  % start with a sweep from K = 0
if nargout > 0, figOut = fig; end

%% ================= Nested functions =================
    function setExample(i)
        stopPlay();
        S.e = i;  e = E(i);
        Km = e.Kmax;

        % root locus: roots of 1 + K G(s) = 0 on a dense gain grid
        S.Kg = unique([0, logspace(-4, log10(Km), 400), linspace(0, Km, 6000), ...
                       linspace(Km, 20*Km, 800)]);
        S.R  = locus(e, S.Kg);
        X = [real(S.R) NaN(size(S.R,1),1)].';  Yl = [imag(S.R) NaN(size(S.R,1),1)].';
        hLoc.XData = X(:);  hLoc.YData = Yl(:);   % all branches in one line, NaN-separated

        p = roots(e.den);  z = roots(e.num);
        hOL.XData = real(p);  hOL.YData = imag(p);
        if isempty(z), hZ.XData = NaN;  hZ.YData = NaN;
        else,          hZ.XData = real(z);  hZ.YData = imag(z);
        end

        % stability limit: first gain where a pole reaches the jω axis
        S.Kcr = Inf;
        mr = max(real(S.R), [], 1);
        j = find(mr > 1e-9 & S.Kg > 0, 1);
        if ~isempty(j) && j > 2
            S.Kcr = fzero(@(K) max(real(roots(charPoly(e, K)))), S.Kg([j-1 j]));
        end
        if isfinite(S.Kcr)
            rc = roots(charPoly(e, S.Kcr));
            rc = rc(abs(real(rc)) < 1e-3 & abs(imag(rc)) > 1e-6);
            hKc.XData = 0*rc;  hKc.YData = imag(rc);
            hKct.Position = [0.15 min(imag(rc))-0.35 0];   % below the axis: K label sits above
            hKct.String = sprintf('K_{cr} = %.2f', S.Kcr);
            btnKcr.Enable = 'on';
        else
            hKc.XData = NaN;  hKc.YData = NaN;  hKct.String = '';
            btnKcr.Enable = 'off';
        end

        lblG.Text = e.texG;  lblC.Text = e.texC;
        sld.Value = 0;  sld.Limits = [0 Km];
        edK.Value = 0;  edK.Limits = [0 Km];
        S.K = Km/5;
        update();
    end

    function update()
        e = E(S.e);  K = S.K;
        r = roots(charPoly(e, K));
        Y = stepCL(e, K);

        % s-plane
        hCL.XData = real(r);  hCL.YData = imag(r);
        [~, it] = max(imag(r));
        hKt.Position = [min(real(r(it))+0.2, xl(2)-1.2), min(imag(r(it))+0.4, yl(2)-0.3), 0];   % stay inside the s-plane
        hKt.String = sprintf('K = %.2f', K);

        % gain controls (only when they really change: each write is a round trip)
        if abs(sld.Value - K) > 1e-9, sld.Value = K; end
        if abs(edK.Value - K) > 1e-9, edK.Value = K; end

        % step response
        hY.YData = Y;

        % readouts
        mr = max(real(r));
        stable = mr < -1e-3;
        setText(val(1), sprintf('%.2f', K));
        if isfinite(S.Kcr), setText(val(2), sprintf('%.2f', S.Kcr));
        else,               setText(val(2), '∞  (always stable)');
        end
        setText(val(3), poleText(r));
        [~, id] = max(real(r));  pd = r(id);           % dominant = closest to the jω axis
        if ~stable,                setText(val(5), '—');
        elseif abs(imag(pd)) < 1e-4, setText(val(5), 'real pole');
        else,                      setText(val(5), sprintf('%.3f', -real(pd)/abs(pd)));
        end
        [os, ts] = metrics(stable);
        setText(val(6), fmt(os, '%.1f %%'));
        setText(val(7), fmt(ts, '%.2f s'));

        % status
        if K == 0
            msg = 'K = 0: no feedback yet. The closed-loop poles sit on the open-loop poles (×).';
            col = [0.4 0.4 0.4];
        elseif mr > 1e-3
            msg = 'UNSTABLE (K > Kcr): poles in the right half-plane, the response grows.';
            col = cR;
        elseif ~stable
            msg = 'MARGINALLY STABLE (K = Kcr): poles on the jω axis, it oscillates forever.';
            col = [0.85 0.45 0];
        elseif isfinite(S.Kcr)
            msg = sprintf('STABLE: all poles in the left half-plane. It stays stable while K < %.2f.', S.Kcr);
            col = cY;
        else
            msg = 'STABLE: all poles in the left half-plane, for every K > 0.';
            col = cY;
        end
        if ~strcmp(lblStat.Text, msg), lblStat.Text = msg;  lblStat.FontColor = col; end
    end

    function y = stepCL(e, K)
        % closed-loop step response K*N/(D + K*N), exact for a step input (ZOH)
        c = charPoly(e, K);  n = numel(c) - 1;
        b = K*[zeros(1, n - numel(e.num)) e.num];
        A = [-c(2:end); eye(n-1) zeros(n-1,1)];        % controllable canonical form
        M = expm([A [1; zeros(n-1,1)]; zeros(1, n+1)]*dt);
        Ad = M(1:n,1:n);  Bd = M(1:n,end);
        x = zeros(n,1);  y = zeros(size(t));
        for k = 2:numel(t)
            x = Ad*x + Bd;
            y(k) = b*x;
            if abs(y(k)) > 1e3, y(k:end) = NaN;  break; end
        end
    end

    function [os, ts] = metrics(stable)
        os = NaN;  ts = NaN;
        if ~stable, return; end
        os = max(0, 100*(max(Y) - 1));
        if os < 0.05, os = 0; end
        iOut = find(abs(Y - 1) > 0.02, 1, 'last');
        if isempty(iOut), ts = 0; elseif iOut < numel(t), ts = t(iOut+1); else, ts = Inf; end
    end

    function s = fmt(v, f)
        if isnan(v), s = '—';
        elseif isinf(v), s = sprintf('> %g s', T);
        else, s = sprintf(f, v);
        end
    end

    function setText(h, str)
        if ~strcmp(h.Text, str), h.Text = str; end
    end

    function onSlider(v)
        stopPlay();
        S.K = min(max(v, 0), E(S.e).Kmax);
        update();
    end

    function goKcr()
        stopPlay();
        S.K = S.Kcr;
        update();
    end

    %% ---- sweep animation ----
    function playPause()
        if S.playing
            stopPlay();
        else
            if S.K >= E(S.e).Kmax - 1e-9, S.K = 0; end   % at the end: start again from 0
            S.Kstart = S.K;  t0 = tic;  S.playing = true;
            btnPlay.Text = '⏸  Pause';
            if isvalid(tmr) && strcmp(tmr.Running, 'off'), start(tmr); end
        end
    end

    function stopPlay()
        S.playing = false;
        btnPlay.Text = '▶  Sweep K';
        if isvalid(tmr) && strcmp(tmr.Running, 'on'), stop(tmr); end
    end

    function tick()
        try
            if ~isvalid(fig) || ~S.playing, return; end
            Km = E(S.e).Kmax;
            K = S.Kstart + toc(t0)*Km/10;             % 0 → Kmax in 10 s
            if K >= Km
                if cbLoop.Value
                    S.Kstart = 0;  t0 = tic;  K = 0;
                else
                    K = Km;  stopPlay();
                end
            end
            S.K = K;
            update();
            drawnow limitrate
        catch err
            if ~strcmp(err.message, lastErr)       % report each error once
                lastErr = err.message;
                fprintf(2, 'RootLocusLab animation: %s\n', err.message);
            end
        end
    end

    %% ---- dragging along the locus ----
    function onDown(~,~)
        cp = axS.CurrentPoint(1,1:2);
        if cp(1) < xl(1) || cp(1) > xl(2) || cp(2) < yl(1) || cp(2) > yl(2), return; end
        S.dragging = true;
        stopPlay();
        pickK(cp);
    end

    function onMove(~,~)
        if ~S.dragging, return; end
        S.cp = axS.CurrentPoint(1,1:2);
        S.pending = true;
        if S.busy, return; end           % still drawing: only keep the latest position
        S.busy = true;
        while S.pending
            S.pending = false;
            pickK(S.cp);
            drawnow limitrate
        end
        S.busy = false;
    end

    function onUp(~,~)
        S.dragging = false;  S.busy = false;  S.pending = false;
    end

    function pickK(cp)
        % the gain whose closed-loop pole is nearest to the mouse
        in = S.Kg <= E(S.e).Kmax;
        d = abs(S.R(:,in) - complex(cp(1), cp(2)));
        [~, k] = min(min(d, [], 1));
        Kin = S.Kg(in);
        S.K = Kin(k);
        update();
    end

    %% ---- compare ----
    function onKeep(~,~)
        r = roots(charPoly(E(S.e), S.K));
        kept(end+1) = plot(axY, t, Y, 'Color',[0.6 0.6 0.6], 'LineWidth',1.2, ...
            'HandleVisibility','off');
        kept(end+1) = plot(axS, real(r), imag(r), 'o', 'Color',[0.6 0.6 0.6], ...
            'MarkerSize',9, 'LineWidth',1.5, 'HitTest','off', 'HandleVisibility','off');
        uistack(hY,'top');  uistack(hCL,'top');
    end

    function onClear(~,~)
        delete(kept(isvalid(kept)));  kept = gobjects(0);
    end

    function closeApp()
        try stop(tmr); delete(tmr); catch, end
        delete(fig);
    end
end

%% ================= Local functions =================
function c = charPoly(e, K)
% characteristic polynomial  D(s) + K*N(s)
c = e.den + K*[zeros(1, numel(e.den) - numel(e.num)) e.num];
end

function R = locus(e, Kg)
% closed-loop poles for every gain in Kg, one row per branch
n = numel(e.den) - 1;
R = zeros(n, numel(Kg));
P = perms(1:n);
prev = roots(e.den);
for i = 1:numel(Kg)
    r = roots(charPoly(e, Kg(i)));
    [~, j] = min(sum(abs(r(P) - prev.'), 2));  % keep each branch continuous
    r = r(P(j,:));
    R(:,i) = r;  prev = r;
end
end

function s = poleText(r)
% "-0.42 ± 0.89j   -3.15"  (each complex pair shown once)
r = r(imag(r) >= -1e-4);
r = sort(r, 'descend', 'ComparisonMethod', 'real');
re = real(r);  re(abs(re) < 5e-3) = 0;        % show 0.00, not -0.00, on the jω axis
r = complex(re, imag(r));
parts = strings(1, numel(r));
for i = 1:numel(r)
    if abs(imag(r(i))) < 1e-4, parts(i) = sprintf('%.2f', real(r(i)));
    else,                      parts(i) = sprintf('%.2f ± %.2fj', real(r(i)), abs(imag(r(i))));
    end
end
s = char(strjoin(parts, '    '));
end
