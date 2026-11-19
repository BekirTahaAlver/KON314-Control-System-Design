function figOut = PIDTermsLab
%PIDTERMSLAB  P vs. PD vs. PI vs. PID: watch what each controller term does.
%
%   KON314 Control System Design
%
%   r --> (+) --e--> F(s) --u--> G(s) --> y
%        - ^                             |
%          '-----------------------------'
%
%   F(s) = Kp + KI/s + Kd*s       u = Kp*e + KI*∫e dt + Kd*de/dt
%
%   Two carts race to the target r = 1. Their position is the output y.
%     - top lane : a reference P controller
%     - bottom   : your controller (P, PD, PI or PID) with its own gains
%   The bars show the P, I and D terms of the control signal u live.
%
%   Plants (Nise examples):
%     Plant 1   : G(s) = 1/(s(s+4)(s+6)),      Nise p.515
%                 P: K = 43.35 (16% OS)  ->  PD: F(s) = 47.45(s+3), Ts/3
%     Plant 2   : G(s) = 1/((s+1)(s+2)(s+10)), Nise p.507
%                 P: K = 164.6 (zeta = 0.174, e_ss = 0.108)
%                 ->  PI: F(s) = 158.2 + 15.82/s, e_ss = 0
%
%   Plain MATLAB (R2024b or newer), no toolboxes needed.

%% ---------------- Settings ----------------
dt = 0.01;
SC = struct( ...
    'item',  {'Plant 1 (type 1):  P is too slow', ...
              'Plant 2 (type 0):  P leaves e_ss ≠ 0'}, ...
    'goal',  {'e_ss = 0 already.  Goal: a faster response.   (Nise p.515)', ...
              'P stops short of r = 1.  Goal: e_ss = 0.   (Nise p.507)'}, ...
    'numG',  {1, 1}, ...
    'denG',  {[1 10 24 0], [1 13 32 20]}, ...
    'texG',  {'$G(s)=\frac{1}{s(s+4)(s+6)}$', '$G(s)=\frac{1}{(s+1)(s+2)(s+10)}$'}, ...
    'KP',    {43.35, 164.6}, ...            % reference P controller
    'type',  {'PD', 'PI'}, ...              % the improved design
    'Kp',    {142.35, 158.2}, ...
    'KI',    {0, 15.82}, ...
    'Kd',    {47.45, 0}, ...
    'T',     {6, 30}, ...                   % simulated time [s]
    'ulim',  {150, 60}, ...                 % bar axis limit
    'rKp',   {[0 300], [0 400]}, ...
    'rKI',   {[0 50], [0 60]}, ...
    'rKd',   {[0 100], [0 100]});

S.sc = 1;
S.playing = false;  S.tc = 0;  S.tStart = 0;  S.speed = 1;
S.ovSrc = [];  S.ovVal = 0;   % slider being dragged and its live value
t = [];  R1 = [];  R2 = [];                % time vector and the two results

cA  = [0.90 0.45 0.00];    % orange : reference P controller
cB  = [0.00 0.35 0.85];    % blue   : your controller
cPt = [0.30 0.55 0.85];    % P term
cIt = [0.20 0.62 0.25];    % I term
cDt = [0.55 0.20 0.75];    % D term
cE  = [0.80 0.00 0.00];    % error
yA = 1.1;  yB = 0;         % lane heights

%% ---------------- Window ----------------
ss  = get(groot,'ScreenSize');
fig = uifigure('Name','PID Terms Lab — P vs. PD vs. PI', ...
    'Position',[40 max(40, ss(4)-880) 1380 min(820, ss(4)-80)]);
g = uigridlayout(fig,[3 3],'ColumnWidth',{'1.35x','1x',340},'RowHeight',{'1x','1x',30});

% ---- race lanes ----
axL = uiaxes(g);  axL.Layout.Row = 1;  axL.Layout.Column = 1;
hold(axL,'on');  axis(axL,'off');
disableDefaultInteractivity(axL);  axL.Toolbar.Visible = 'off';
axL.XLim = [-0.45 1.9];  axL.YLim = [-0.7 1.85];
plot(axL,[1 1],[-0.45 1.6],'--','Color',[0.2 0.6 0.2],'LineWidth',1.5);
text(axL,1,1.76,'target  r = 1','HorizontalAlignment','center','Color',[0.2 0.6 0.2],'FontWeight','bold');
plot(axL,[0 0],[-0.45 1.6],':','Color',[0.5 0.5 0.5]);
plot(axL,[0 1.5],[-0.45 -0.45],'Color',[0.5 0.5 0.5]);           % position scale
for xs = 0:0.5:1.5
    plot(axL,[xs xs],[-0.45 -0.40],'Color',[0.5 0.5 0.5]);
    text(axL,xs,-0.56,sprintf('%g',xs),'HorizontalAlignment','center','FontSize',11,'Color',[0.5 0.5 0.5]);
end
text(axL,-0.06,-0.56,'y =','HorizontalAlignment','right','FontSize',11,'Color',[0.5 0.5 0.5]);
for yl = [yA yB]
    plot(axL,[-0.2 1.85],[yl yl]-0.13,'k','LineWidth',1.2);
end
hNameA = text(axL,-0.42,yA,'P','FontSize',14,'FontWeight','bold','Color',cA);
hNameB = text(axL,-0.42,yB,'PD','FontSize',14,'FontWeight','bold','Color',cB);
[hCarA, hWhA] = makeCart(cA);
[hCarB, hWhB] = makeCart(cB);
cU = [0.95 0.70 0.10];     % gold : force arrow u
hArA = plot(axL,NaN,NaN,'-','Color',cU,'LineWidth',3.5);
hArB = plot(axL,NaN,NaN,'-','Color',cU,'LineWidth',3.5);
hHdA = patch(axL,NaN,NaN,cU,'EdgeColor','none');
hHdB = patch(axL,NaN,NaN,cU,'EdgeColor','none');
hUtA = text(axL,0,0,'','Color',cU,'FontWeight','bold','FontSize',12);
hUtB = text(axL,0,0,'','Color',cU,'FontWeight','bold','FontSize',12);
hErA = plot(axL,NaN,NaN,'-','Color',cE,'LineWidth',2);
hErB = plot(axL,NaN,NaN,'-','Color',cE,'LineWidth',2);
hEtA = text(axL,0,0,'','Color',cE,'FontWeight','bold','HorizontalAlignment','center');
hEtB = text(axL,0,0,'','Color',cE,'FontWeight','bold','HorizontalAlignment','center');
title(axL,'');

% ---- control terms (bars, aligned with the lanes) ----
axB = uiaxes(g);  axB.Layout.Row = 1;  axB.Layout.Column = 2;
hold(axB,'on');  box(axB,'on');  grid(axB,'on');
disableDefaultInteractivity(axB);  axB.Toolbar.Visible = 'off';
axB.YLim = axL.YLim;  axB.TickLabelInterpreter = 'none';
plot(axB,[0 0],axB.YLim,'k');
plot(axB,[-1e4 1e4],[1 1]*(yA+yB+0.45)/2,':','Color',[0.5 0.5 0.5],'LineWidth',1.2);   % lane separator
hBarA  = patch(axB,NaN,NaN,cA,'EdgeColor','none');
hBarP  = patch(axB,NaN,NaN,cPt,'EdgeColor','none');
hBarI  = patch(axB,NaN,NaN,cIt,'EdgeColor','none');
hBarD  = patch(axB,NaN,NaN,cDt,'EdgeColor','none');
hBarU  = patch(axB,NaN,NaN,cB,'EdgeColor','none');
hValA  = text(axB,0,0,'');  hValP = text(axB,0,0,'');
hValI  = text(axB,0,0,'');  hValD = text(axB,0,0,'');  hValU = text(axB,0,0,'');
yBars = [yB-0.45 yB-0.15 yB+0.15 yB+0.45 yA];   % u, D, I, P (your controller), u (P lane)
xlabel(axB,'Control signal terms');
title(axB,'u = Kp·e + KI·∫e + Kd·ė');

% ---- output y(t) ----
axY = uiaxes(g);  axY.Layout.Row = 2;  axY.Layout.Column = 1;
hold(axY,'on'); grid(axY,'on'); box(axY,'on');
disableDefaultInteractivity(axY);  axY.Toolbar.Visible = 'off';
hBand = patch(axY,NaN,NaN,[0.2 0.6 0.2],'FaceAlpha',0.12,'EdgeColor','none','DisplayName','±2% around r = 1');
hRef  = plot(axY,NaN,NaN,'k--','DisplayName','Reference r = 1');
hFA = plot(axY,NaN,NaN,'Color',[cA 0.25],'LineWidth',1.5,'HandleVisibility','off');
hFB = plot(axY,NaN,NaN,'Color',[cB 0.25],'LineWidth',1.5,'HandleVisibility','off');
hYA = plot(axY,NaN,NaN,'Color',cA,'LineWidth',2.2,'DisplayName','P (reference)');
hYB = plot(axY,NaN,NaN,'Color',cB,'LineWidth',2.2,'DisplayName','Your controller');
hCA = plot(axY,NaN,NaN,'o','MarkerFaceColor',cA,'MarkerEdgeColor','none','MarkerSize',8,'HandleVisibility','off');
hCB = plot(axY,NaN,NaN,'o','MarkerFaceColor',cB,'MarkerEdgeColor','none','MarkerSize',8,'HandleVisibility','off');
xlabel(axY,'Time [s]');  ylabel(axY,'Output y');  title(axY,'Closed-loop step response');
axY.YLim = [-0.2 1.9];
legend(axY,[hBand hRef hYA hYB],'Location','southeast');

% ---- control signal u(t) ----
axU = uiaxes(g);  axU.Layout.Row = 2;  axU.Layout.Column = 2;
hold(axU,'on'); grid(axU,'on'); box(axU,'on');
disableDefaultInteractivity(axU);  axU.Toolbar.Visible = 'off';
plot(axU,[0 1e3],[0 0],'Color',[0.5 0.5 0.5],'HandleVisibility','off');
hUFA = plot(axU,NaN,NaN,'Color',[cA 0.25],'LineWidth',1.5,'HandleVisibility','off');
hUFB = plot(axU,NaN,NaN,'Color',[cB 0.25],'LineWidth',1.5,'HandleVisibility','off');
hUA  = plot(axU,NaN,NaN,'Color',cA,'LineWidth',2.2,'DisplayName','P (reference)');
hUB  = plot(axU,NaN,NaN,'Color',cB,'LineWidth',2.2,'DisplayName','Your controller');
hUCA = plot(axU,NaN,NaN,'o','MarkerFaceColor',cA,'MarkerEdgeColor','none','MarkerSize',8,'HandleVisibility','off');
hUCB = plot(axU,NaN,NaN,'o','MarkerFaceColor',cB,'MarkerEdgeColor','none','MarkerSize',8,'HandleVisibility','off');
xlabel(axU,'Time [s]');  ylabel(axU,'Control signal u');
title(axU,'Control signal u(t)   (D term drawn for t > 0)');
legend(axU,[hUA hUB],'Location','northeast');

% ---- time scrubber ----
rowS = uigridlayout(g,[1 2],'ColumnWidth',{60,'1x'},'Padding',[10 0 10 0]);
rowS.Layout.Row = 3;  rowS.Layout.Column = [1 2];
uilabel(rowS,'Text','Time','FontWeight','bold','FontSize',13);
sT = uislider(rowS,'MajorTicks',[],'MinorTicks',[],'Limits',[0 1], ...
    'ValueChangingFcn',@(~,ev) scrubTo(ev.Value),'ValueChangedFcn',@(s,~) scrubTo(s.Value));

%% ---------------- Side panel ----------------
side = uigridlayout(g,[15 1],'RowHeight',{22,30,44,20,22,34,26,34,30,30,30,28,104,56,'1x'}, ...
    'RowSpacing',5);
side.Layout.Row = [1 3];  side.Layout.Column = 3;

uilabel(side,'Text','Plant  G(s)','FontWeight','bold');
ddSc = uidropdown(side,'Items',{SC.item},'ValueChangedFcn',@(s,~) setScenario(find(strcmp(s.Items, s.Value))));
lblG = uilabel(side,'Interpreter','latex','FontSize',16,'HorizontalAlignment','center');
lblGoal = uilabel(side,'HorizontalAlignment','center','FontAngle','italic');
uilabel(side,'Text','Reference P controller','FontWeight','bold','FontColor',cA);
lblFA = uilabel(side,'Interpreter','latex','FontSize',15,'HorizontalAlignment','center');

rowT = uigridlayout(side,[1 2],'ColumnWidth',{'1x',90},'Padding',[0 0 0 0]);
uilabel(rowT,'Text','Your controller','FontWeight','bold','FontColor',cB);
ddType = uidropdown(rowT,'Items',{'P','PD','PI','PID'},'ValueChangedFcn',@(~,~) onType());
lblFB = uilabel(side,'Interpreter','latex','FontSize',15,'HorizontalAlignment','center');

[sKp, vKp] = gainRow('Kp', cPt);
[sKI, vKI] = gainRow('KI', cIt);
[sKd, vKd] = gainRow('Kd', cDt);
uibutton(side,'Text','Reset gains','ButtonPushedFcn',@(~,~) setScenario(S.sc));

tab = uigridlayout(side,[4 3],'ColumnWidth',{'1x',80,80},'RowHeight',{22,22,22,22}, ...
    'Padding',[0 0 0 0],'RowSpacing',2);
uilabel(tab,'Text','');
uilabel(tab,'Text','P','FontWeight','bold','FontSize',13,'FontColor',cA,'HorizontalAlignment','right');
hHdrB = uilabel(tab,'Text','PD','FontWeight','bold','FontSize',13,'FontColor',cB,'HorizontalAlignment','right');
mNames = {'%OS  overshoot','Ts  (2% of final value)','e_ss  (step input)'};
vA = gobjects(3,1);  vB = gobjects(3,1);
for i = 1:3
    uilabel(tab,'Text',mNames{i},'FontWeight','bold','FontSize',13);
    vA(i) = uilabel(tab,'Text','','FontName','Menlo','FontSize',13,'HorizontalAlignment','right');
    vB(i) = uilabel(tab,'Text','','FontName','Menlo','FontSize',13,'HorizontalAlignment','right');
end

lblStat = uilabel(side,'WordWrap','on','FontWeight','bold','FontSize',13,'VerticalAlignment','top');

low = uigridlayout(side,[3 2],'RowHeight',{36,30,'1x'},'Padding',[0 0 0 0]);
uibutton(low,'Text','▶  Play','FontWeight','bold','FontSize',14, ...
    'BackgroundColor',[0.80 0.93 0.80],'FontColor',[0 0 0],'ButtonPushedFcn',@(~,~) play());
btnPause = uibutton(low,'Text','⏸  Pause','FontSize',14,'Enable','off', ...
    'ButtonPushedFcn',@(~,~) pauseResume());
uidropdown(low,'Items',{'Speed 0.25×','Speed 0.5×','Speed 1×','Speed 2×'},'Value','Speed 1×', ...
    'ValueChangedFcn',@(s,~) setSpeed(s.Value));
cbLoop = uicheckbox(low,'Text','Loop','Value',false);
hint = uilabel(low,'WordWrap','on','VerticalAlignment','top','Text', ...
    ['What each term does:' newline ...
     '•  P (Kp·e): pushes in proportion to e. No error, no push.' newline ...
     '•  D (Kd·ė): reacts to how fast e changes, brakes early.' newline ...
     '•  I (KI·∫e): adds up past error, so e_ss = 0.' newline ...
     '•  Gold arrow on a cart = control signal u (push or brake).']);
hint.Layout.Row = 3;  hint.Layout.Column = [1 2];

%% ---------------- Start ----------------
t0  = tic;
lastErr = '';
tmr = timer('ExecutionMode','fixedSpacing','Period',0.03,'BusyMode','drop', ...
    'TimerFcn',@(~,~) tick());
fig.CloseRequestFcn = @(~,~) closeApp();

setScenario(1);
if nargout > 0, figOut = fig; end

%% ================= Nested functions =================
    function [hc, hw] = makeCart(col)
        hc = patch(axL,NaN,NaN,col,'EdgeColor','k','LineWidth',1.2,'FaceAlpha',0.85);
        hw = plot(axL,NaN,NaN,'o','MarkerFaceColor',[0.2 0.2 0.2],'MarkerEdgeColor','k','MarkerSize',7);
    end

    function [s, v] = gainRow(name, col)
        row = uigridlayout(side,[1 3],'ColumnWidth',{30,'1x',62},'Padding',[0 0 0 0]);
        uilabel(row,'Text',name,'FontWeight','bold','FontColor',col);
        s = uislider(row,'MajorTicks',[],'MinorTicks',[], ...
            'ValueChangingFcn',@(src,ev) onSliding(src, ev.Value), ...
            'ValueChangedFcn',@(~,~) onGain(true));
        v = uilabel(row,'Text','','FontName','Menlo','HorizontalAlignment','right');
    end

    function setScenario(i)
        stopPlay();
        S.sc = i;  sc = SC(i);
        t = (0:dt:sc.T)';
        ddSc.Value = sc.item;
        lblG.Text = sc.texG;
        lblGoal.Text = sc.goal;
        lblFA.Text = sprintf('$F(s)=K=%.2f$', sc.KP);
        ddType.Value = sc.type;
        setSlider(sKp, sc.rKp, sc.Kp);
        setSlider(sKI, sc.rKI, sc.KI);
        setSlider(sKd, sc.rKd, sc.Kd);

        axY.XLim = [0 sc.T];  axU.XLim = [0 sc.T];
        sT.Value = 0;  sT.Limits = [0 sc.T];
        hBand.XData = [0 sc.T sc.T 0];  hBand.YData = [0.98 0.98 1.02 1.02];
        hRef.XData = [0 sc.T];  hRef.YData = [1 1];
        axB.XLim = 1.3*sc.ulim*[-1 1];

        R1 = simulate(sc.KP, 0, 0);
        showMetrics(vA, R1);
        hFA.XData = t;  hFA.YData = R1.y;
        hUFA.XData = t;  hUFA.YData = R1.u;
        onGain(true);
    end

    function setSlider(s, lim, v)
        s.Value = lim(1);  s.Limits = lim;  s.Value = min(max(v, lim(1)), lim(2));
    end

    function v = sv(s)
        % slider value, or the live value of the slider being dragged
        if ~isempty(S.ovSrc) && S.ovSrc == s, v = S.ovVal; else, v = s.Value; end
    end

    function [Kp, KI, Kd] = gains()
        Kp = sv(sKp);  KI = sv(sKI);  Kd = sv(sKd);
        typ = ddType.Value;
        if ~contains(typ, 'I'), KI = 0; end
        if ~contains(typ, 'D'), Kd = 0; end
    end

    function onSliding(src, v)
        % live update while a slider is dragged (the carts wait at the start)
        stopPlay();
        S.ovSrc = src;  S.ovVal = v;
        recompute();
        showTime(0);
    end

    function onType()
        % a new type starts with a sensible value for its extra gain
        typ = ddType.Value;
        if contains(typ, 'I') && sKI.Value == 0
            sKI.Value = min(0.1*sKp.Value, sKI.Limits(2));     % PI zero at s = -0.1
        end
        if contains(typ, 'D') && sKd.Value == 0
            sKd.Value = min(sKp.Value/3, sKd.Limits(2));       % PD zero at s = -3
        end
        onGain(true);
    end

    function onGain(autoPlay)
        S.ovSrc = [];                      % dragging is over: sliders hold their values
        sKI.Enable = contains(ddType.Value, 'I');
        sKd.Enable = contains(ddType.Value, 'D');
        recompute();
        if autoPlay, play(); else, showTime(0); end
    end

    function recompute()
        [Kp, KI, Kd] = gains();
        vKp.Text = sprintf('%.2f', sv(sKp));
        vKI.Text = sprintf('%.2f', sv(sKI));
        vKd.Text = sprintf('%.2f', sv(sKd));
        vKI.Enable = sKI.Enable;  vKd.Enable = sKd.Enable;     % theme greys out unused gains

        R2 = simulate(Kp, KI, Kd);
        showMetrics(vB, R2);
        hFB.XData = t;  hFB.YData = R2.y;
        hUFB.XData = t;  hUFB.YData = R2.u;
        um = max(abs([R1.u; R2.u]), [], 'omitnan');            % u axis fits both runs
        um = min(max(um, 1), 3*SC(S.sc).ulim);
        axU.YLim = 1.1*um*[-1 1];

        typ = ddType.Value;
        hNameB.String = typ;  hHdrB.Text = typ;
        lblFB.Text = texF(typ, Kp, KI, Kd);
        hasI = contains(typ, 'I');  hasD = contains(typ, 'D');
        set([hBarI hValI], 'Visible', hasI);
        set([hBarD hValD], 'Visible', hasD);
        lI = '';  lD = '';
        if hasI, lI = 'I:  KI·∫e'; end
        if hasD, lD = 'D:  Kd·ė'; end
        axB.YTick = yBars;
        axB.YTickLabel = {'u  (total)', lD, lI, 'P:  Kp·e', 'u = Kp·e'};

        % status
        if ~R2.stable
            msg = 'UNSTABLE: your gains push the poles into the right half-plane. Lower them.';
            col = cE;
        else
            switch typ
                case 'PD', msg = 'PD: the D term (purple) turns negative while y rises fast. It brakes early, so the cart settles sooner.';
                case 'PI', msg = 'PI: the I term (green) keeps growing until e = 0, and then holds u. The cart reaches the target exactly.';
                case 'PID', msg = 'PID: the D term (purple) brakes the overshoot, the I term (green) removes the steady-state error.';
                otherwise, msg = 'P: u = Kp·e. When e → 0 the push disappears, so a type-0 plant stops short of the target.';
            end
            col = cB;
        end
        lblStat.Text = msg;  lblStat.FontColor = col;
    end

    function s = texF(typ, Kp, KI, Kd)
        switch typ
            case 'PD'
                if Kd > 0
                    s = sprintf('$F(s)=%.2f+%.2fs=%.2f(s+%.2f)$', Kp, Kd, Kd, Kp/Kd);
                else
                    s = sprintf('$F(s)=%.2f$', Kp);
                end
            case 'PI'
                if KI == 0
                    s = sprintf('$F(s)=%.2f$', Kp);
                elseif Kp > 0
                    s = sprintf('$F(s)=%.2f+\\frac{%.2f}{s}=%.2f\\,\\frac{s+%.3g}{s}$', Kp, KI, Kp, KI/Kp);
                else
                    s = sprintf('$F(s)=\\frac{%.2f}{s}$', KI);
                end
            case 'PID'                       % parallel form only (the zeros may be complex)
                s = sprintf('$F(s)=%.2f+\\frac{%.2f}{s}+%.2fs$', Kp, KI, Kd);
            otherwise
                s = sprintf('$F(s)=K=%.2f$', Kp);
        end
    end

    function R = simulate(Kp, KI, Kd)
        % closed-loop step response of F(s)G(s)/(1+F(s)G(s)), with its terms
        sc = SC(S.sc);
        if KI > 0, numF = [Kd Kp KI];  denF = [1 0];
        else,      numF = [Kd Kp];     denF = 1;
        end
        numL = conv(numF, sc.numG);  denL = conv(denF, sc.denG);
        c = denL + [zeros(1, numel(denL) - numel(numL)) numL];
        n = numel(c) - 1;
        b = [zeros(1, n - numel(numL) + 1) numL];  b = b(end-n+1:end);
        A = [-c(2:end); eye(n-1) zeros(n-1,1)];        % controllable canonical form
        B = [1; zeros(n-1,1)];
        M = expm([A B; zeros(1, n+1)]*dt);
        Ad = M(1:n,1:n);  Bd = M(1:n,end);
        N = numel(t);  x = zeros(n,1);
        y = zeros(N,1);  yd = zeros(N,1);  yd(1) = b*B;
        for k = 2:N
            x = Ad*x + Bd;
            y(k) = b*x;  yd(k) = b*(A*x + B);
            if abs(y(k)) > 1e3, y(k:end) = NaN;  yd(k:end) = NaN;  break; end
        end
        R.y = y;
        e = 1 - y;
        R.P = Kp*e;
        R.I = KI*cumtrapz(t, e);
        R.D = -Kd*yd;                                   % de/dt = -dy/dt for t > 0
        R.u = R.P + R.I + R.D;
        R.stable = max(real(roots(c))) < -1e-6;

        % steady-state error for a unit step: 1/(1 + lim F G), 0 if the loop has an integrator
        R.ess = NaN;
        if R.stable
            if abs(denL(end)) < 1e-12, R.ess = 0;
            else, R.ess = 1/(1 + numL(end)/denL(end));
            end
        end
    end

    function showMetrics(v, R)
        os = NaN;  ts = NaN;
        yf = 1 - R.ess;                                 % final value
        if R.stable && yf > 1e-6
            os = max(0, 100*(max(R.y) - yf)/yf);
            if os < 0.05, os = 0; end
            iOut = find(abs(R.y - yf) > 0.02*yf, 1, 'last');
            if isempty(iOut), ts = 0; elseif iOut < numel(t), ts = t(iOut+1); else, ts = Inf; end
        end
        v(1).Text = fmt(os, '%.1f %%');
        v(2).Text = fmt(ts, '%.2f s');
        v(3).Text = fmt(R.ess, '%.3f');
    end

    function s = fmt(v, f)
        if isnan(v), s = '—';
        elseif isinf(v), s = sprintf('> %g s', t(end));
        else, s = sprintf(f, v);
        end
    end

    %% ---- drawing one moment in time ----
    function showTime(tc)
        S.tc = tc;
        k = min(round(tc/dt) + 1, numel(t));
        L = SC(S.sc).ulim;
        drawCart(hCarA, hWhA, hErA, hEtA, R1.y(k), yA);
        drawCart(hCarB, hWhB, hErB, hEtB, R2.y(k), yB);
        drawArrow(hArA, hHdA, hUtA, R1.y(k), R1.u(k), yA, L);
        drawArrow(hArB, hHdB, hUtB, R2.y(k), R2.u(k), yB, L);
        set(hYA, 'XData', t(1:k), 'YData', R1.y(1:k));
        set(hYB, 'XData', t(1:k), 'YData', R2.y(1:k));
        set(hCA, 'XData', t(k), 'YData', clipY(R1.y(k)));
        set(hCB, 'XData', t(k), 'YData', clipY(R2.y(k)));
        set(hUA, 'XData', t(1:k), 'YData', R1.u(1:k));
        set(hUB, 'XData', t(1:k), 'YData', R2.u(1:k));
        set(hUCA, 'XData', t(k), 'YData', min(max(R1.u(k), axU.YLim(1)), axU.YLim(2)));
        set(hUCB, 'XData', t(k), 'YData', min(max(R2.u(k), axU.YLim(1)), axU.YLim(2)));
        setBar(hBarA, hValA, R1.u(k), yBars(5), L);
        setBar(hBarP, hValP, R2.P(k), yBars(4), L);
        setBar(hBarI, hValI, R2.I(k), yBars(3), L);
        setBar(hBarD, hValD, R2.D(k), yBars(2), L);
        setBar(hBarU, hValU, R2.u(k), yBars(1), L);
        axL.Title.String = sprintf('Race to the target: cart position = output y      t = %.2f / %g s', tc, t(end));
        if abs(sT.Value - tc) > 1e-9, sT.Value = min(tc, sT.Limits(2)); end
    end

    function y = clipY(y)
        if ~isfinite(y), y = axY.YLim(2); end
        y = min(max(y, axY.YLim(1)), axY.YLim(2));
    end

    function drawCart(hc, hw, he, ht, y, yl)
        if ~isfinite(y), y = 1.85; end
        x = min(max(y, -0.2), 1.85);
        w = 0.13;
        hc.XData = x + [-w w w -w];  hc.YData = yl + [-0.08 -0.08 0.2 0.2];
        hw.XData = x + [-0.7 0.7]*w;  hw.YData = [yl yl] - 0.09;
        e = 1 - y;
        if abs(e) > 0.005
            he.XData = [x 1];  he.YData = [yl yl] + 0.3;
            ht.Position = [(x + 1)/2, yl + 0.42, 0];
            ht.String = sprintf('e = %.3f', e);
        else
            he.XData = NaN;  he.YData = NaN;  ht.String = '';
        end
    end

    function drawArrow(hl, hh, ht, y, u, yl, L)
        % force arrow on the cart: length ∝ u, pointing the way u pushes
        if ~isfinite(y) || ~isfinite(u) || abs(u) < 0.02*L
            hl.XData = NaN;  hl.YData = NaN;  hh.XData = NaN;  hh.YData = NaN;  ht.String = '';
            return
        end
        x = min(max(y, -0.2), 1.85);  w = 0.13;  ya = yl + 0.06;
        len = 0.45*min(abs(u)/L, 1);  d = sign(u);
        x0 = x + d*w;  x1 = x0 + d*len;
        hl.XData = [x0 x1 - d*0.04];  hl.YData = [ya ya];
        hh.XData = [x1 - d*0.06, x1 - d*0.06, x1];  hh.YData = ya + [-0.07 0.07 0];
        ht.Position = [x1 + d*0.02, ya, 0];  ht.String = 'u';
        if d > 0, ht.HorizontalAlignment = 'left'; else, ht.HorizontalAlignment = 'right'; end
    end

    function setBar(h, ht, v, yc, L)
        if ~isfinite(v), v = 0; end
        x = min(max(v, -L), L);                    % clipped bars still show the true value
        h.XData = [0 x x 0];  h.YData = yc + [-0.11 -0.11 0.11 0.11];
        if abs(v) > L                              % clipped: write the value inside the bar
            ht.HorizontalAlignment = 'center';  ht.Position = [x/2, yc, 0];
        elseif x >= 0, ht.HorizontalAlignment = 'left';   ht.Position = [x + 0.03*L, yc, 0];
        else,          ht.HorizontalAlignment = 'right';  ht.Position = [x - 0.03*L, yc, 0];
        end
        if v > L,      ht.String = sprintf('▶ %.1f', v);     % bar is clipped: it goes on
        elseif v < -L, ht.String = sprintf('%.1f ◀', v);
        else,          ht.String = sprintf('%.1f', v);
        end
    end

    function scrubTo(v)
        % time slider: pause and show that moment; Resume continues from here
        if S.playing, pauseResume(); end
        btnPause.Enable = 'on';  btnPause.Text = '▶  Resume';
        showTime(v);
    end

    %% ---- animation ----
    function tick()
        try
            if ~isvalid(fig) || ~S.playing, return; end
            T = t(end);
            tc = S.tStart + toc(t0)*S.speed*T/10;   % the whole run takes 10 s at 1x
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
            if ~strcmp(err.message, lastErr)
                lastErr = err.message;
                fprintf(2, 'PIDTermsLab animation: %s\n', err.message);
            end
        end
    end

    function play()
        S.tStart = 0;  t0 = tic;  S.playing = true;
        btnPause.Enable = 'on';  btnPause.Text = '⏸  Pause';
        showTime(0);
        if isvalid(tmr) && strcmp(tmr.Running, 'off'), start(tmr); end
    end

    function pauseResume()
        if S.playing
            S.playing = false;  btnPause.Text = '▶  Resume';
            if isvalid(tmr) && strcmp(tmr.Running, 'on'), stop(tmr); end
        else
            S.tStart = S.tc;  t0 = tic;  S.playing = true;
            btnPause.Text = '⏸  Pause';
            if isvalid(tmr) && strcmp(tmr.Running, 'off'), start(tmr); end
        end
    end

    function stopPlay()
        S.playing = false;
        if exist('btnPause','var') && isvalid(btnPause)
            btnPause.Enable = 'off';  btnPause.Text = '⏸  Pause';
        end
        if exist('tmr','var') && isvalid(tmr) && strcmp(tmr.Running, 'on'), stop(tmr); end
    end

    function setSpeed(v)
        S.tStart = S.tc;  t0 = tic;
        S.speed = sscanf(v, 'Speed %f');
    end

    function closeApp()
        try stop(tmr); delete(tmr); catch, end
        delete(fig);
    end
end
