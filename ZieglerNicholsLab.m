function ZieglerNicholsLab
%ZIEGLERNICHOLSLAB  Ziegler–Nichols (closed-loop) PID tuning of a heated water tank.
%
%   KON314 Control System Design
%
%   1. Increase the gain K slowly (P-only control).
%   2. When the temperature oscillates with CONSTANT amplitude, K is the
%      critical gain Kcr. The app measures the period Pc and wc = 2*pi/Pc.
%   3. The Ziegler–Nichols table then gives the P, PI and PID gains.
%
%   Process: a stirred water tank heated by a 10 kW heater. The temperature
%   sensor sits at the end of an outlet pipe, so the measurement is delayed
%   by about 30 s. The reference is a 1 °C step from 40 °C to 41 °C.
%
%   Plain MATLAB, no toolboxes needed.

%% ---------------- Simulation settings ----------------
dt = 0.5;                 % time step [s]
t  = (0:dt:3000)';        % simulated time [s]
y0 = 40;                  % operating point [°C]
u0 = 43.9;                % heater power at the operating point [%]
r  = 1;                   % reference step [°C]

%% ---------------- Plant (heated tank) ----------------
p.Pmax  = 10e3;           % heater power [W]
p.Ch    = 6000;           % heater heat capacity [J/K]
p.hA    = 150;            % heater -> water [W/K]
p.Ct    = 20*4186;        % 20 L of water [J/K]
p.wUA   = 0.04*4186 + 10; % outflow (2.4 L/min) + wall losses [W/K]
p.tauS  = 15;             % sensor time constant [s]
p.delay = 30;             % pipe transport delay [s]

%% ---------------- Transfer function G(s) = Y(s)/U(s) ----------------
% Laplace transform of the energy balances (deviation variables):
%   heater : Ch*s*Th = (Pmax/100)*U - hA*(Th - Tt)
%   tank   : Ct*s*Tt = hA*(Th - Tt) - wUA*Tt
%   sensor : Y = exp(-delay*s)/(tauS*s + 1) * Tt
% gives  G(s) = K0*exp(-delay*s) / ((tau1*s+1)(tau2*s+1)(tauS*s+1))
a  = [p.Ch*p.Ct, p.Ch*(p.hA + p.wUA) + p.hA*p.Ct, p.hA*p.wUA];   % denominator of Tt/U
K0 = (p.Pmax/100)/p.wUA;                                         % static gain [°C/%]
tau = sort(-1./roots(a), 'descend');                             % tank & heater time constants [s]

%% ---------------- User interface ----------------
ss  = get(groot,'ScreenSize');
fig = uifigure('Name','Ziegler–Nichols Tuning — Heated Water Tank', ...
    'Position',[60 max(40, ss(4)-900) 1260 min(850, ss(4)-80)]);
g   = uigridlayout(fig,[1 2],'ColumnWidth',{'1x',430});

gp  = uigridlayout(g,[2 1],'RowHeight',{'2x','1x'});
axY = uiaxes(gp);  axU = uiaxes(gp);
hold(axY,'on'); grid(axY,'on'); box(axY,'on');
hold(axU,'on'); grid(axU,'on'); box(axU,'on');
plot(axY, t, y0 + r*ones(size(t)), 'k--', 'DisplayName','Reference r');
hY   = plot(axY, t, nan(size(t)), 'b',  'LineWidth',1.6, 'DisplayName','P control, gain K');
hYp  = plot(axY, t, nan(size(t)), 'Color',[0 0.6 0.2], 'LineWidth',1.6, 'DisplayName','ZN-PID', 'Visible','off');
hU   = plot(axU, t, nan(size(t)), 'b',  'LineWidth',1.4);
hUp  = plot(axU, t, nan(size(t)), 'Color',[0 0.6 0.2], 'LineWidth',1.4, 'Visible','off');
ylabel(axY,'Temperature y [°C]');  title(axY,'System output');
ylabel(axU,'Heater power u [%]');  xlabel(axU,'Time [s]');  title(axU,'Control signal');
legend(axY,'Location','southeast');
linkaxes([axY axU],'x');  axY.XLim = [0 t(end)];

side = uigridlayout(g,[12 2],'RowHeight',{115,16,50,34,22,40,24,60,100,20,165,24}, ...
    'ColumnWidth',{'1x',110},'RowSpacing',6);
axS = uiaxes(side);  axS.Layout.Column = [1 2];
drawSketch(axS);

cap = uilabel(side,'Text','Plant transfer function   (u [%]  →  y [°C])','FontWeight','bold');
cap.Layout.Column = [1 2];
axG = eqAxes(side);
text(axG, 0.5, 0.5, sprintf('$G(s)=\\frac{Y(s)}{U(s)}=\\frac{%.3f\\,e^{-%gs}}{(%.1fs+1)(%.1fs+1)(%gs+1)}$', ...
    K0, p.delay, tau(1), tau(2), p.tauS), 'Interpreter','latex','FontSize',16, ...
    'HorizontalAlignment','center');

info = uilabel(side,'WordWrap','on','Text', ...
    ['P-only control: u = K·e. Increase K slowly until the oscillation ' ...
     'neither grows nor decays.']);
info.Layout.Column = [1 2];

uilabel(side,'Text','Gain  K  [%/°C]','FontWeight','bold');
spK = uispinner(side,'Limits',[0.1 40],'Step',0.1,'Value',5,'ValueDisplayFormat','%.1f');
slK = uislider(side,'Limits',[0 40],'MajorTicks',0:5:40,'Value',5);
slK.Layout.Column = [1 2];

lblStatus = uilabel(side,'WordWrap','on','FontSize',15,'FontWeight','bold','Text',' ');
lblStatus.Layout.Column = [1 2];

lblCrit = uilabel(side,'FontName','Menlo','FontSize',14,'Text',sprintf(' \n \n '));
lblCrit.Layout.Column = [1 2];

tbl = uitable(side,'ColumnName',{'ZN','Kp','Ti [s]','Td [s]'},'RowName',{}, ...
    'ColumnWidth',{45,'1x','1x','1x'});
tbl.Layout.Column = [1 2];

lblC = uilabel(side,'Text','PID controller','FontWeight','bold');
lblC.Layout.Column = [1 2];
axC = eqAxes(side);
ltx = {'Interpreter','latex','HorizontalAlignment','center'};
text(axC, 0.5, 0.87, '$C(s)=K_p\left(1+\frac{1}{T_i s}+T_d s\right)=K_p+\frac{K_i}{s}+K_d s$', ltx{:}, 'FontSize',15);
text(axC, 0.5, 0.62, '$K_i=\frac{K_p}{T_i},\qquad K_d=K_p\,T_d$', ltx{:}, 'FontSize',15);
eqN1 = text(axC, 0.5, 0.36, '', ltx{:}, 'FontSize',14);
eqN2 = text(axC, 0.5, 0.11, '', ltx{:}, 'FontSize',14);

cbPID = uicheckbox(side,'Text','Show the closed-loop response with ZN-PID','Enable','off');
cbPID.Layout.Column = [1 2];

% callbacks
spK.ValueChangedFcn  = @(s,~) setK(s.Value);
slK.ValueChangingFcn = @(~,e) setK(round(e.Value,1));
slK.ValueChangedFcn  = @(s,~) setK(round(s.Value,1));
cbPID.ValueChangedFcn = @(~,~) update();

update();

%% ---------------- Callbacks ----------------
    function setK(K)
        K = max(K, 0.1);
        spK.Value = K;  slK.Value = K;
        update();
    end

    function update()
        K = spK.Value;
        [y, u] = simulate(K, Inf, 0);                  % P-only
        hY.YData = y0 + y;  hU.YData = u0 + u;
        [ratio, Pc] = analyse(y);

        if isnan(ratio)
            status = 'No oscillation yet  →  increase K';       col = [0.45 0.45 0.45];
        elseif ratio < 0.97
            status = sprintf('Decaying (ratio %.2f)  →  increase K', ratio);  col = [0.85 0.5 0];
        elseif ratio > 1.03
            status = sprintf('Growing (ratio %.2f)  →  decrease K', ratio);   col = [0.85 0.1 0.1];
        else
            status = sprintf('Sustained oscillation!  K = Kcr');               col = [0 0.6 0.2];
        end
        lblStatus.Text = status;  lblStatus.FontColor = col;

        found = ~isnan(ratio) && abs(ratio - 1) <= 0.03;
        if found
            Kcr = K;  wc = 2*pi/Pc;
            lblCrit.Text = sprintf('Kcr = %6.2f  %%/°C\nPc  = %6.1f  s\nωc  = %6.4f rad/s', Kcr, Pc, wc);
            Z = [0.5*Kcr  Inf     0
                 0.45*Kcr Pc/1.2  0
                 0.6*Kcr  Pc/2    Pc/8];
            tbl.Data = {'P',   f(Z(1,1)), '—',      '—'
                        'PI',  f(Z(2,1)), f(Z(2,2)), '—'
                        'PID', f(Z(3,1)), f(Z(3,2)), f(Z(3,3))};
            Kp = Z(3,1);  Ti = Z(3,2);  Td = Z(3,3);
            eqN1.String = sprintf('$C_{ZN}(s)=%.2f\\left(1+\\frac{1}{%.1f\\,s}+%.2f\\,s\\right)$', Kp, Ti, Td);
            eqN2.String = sprintf('$=%.2f+\\frac{%.4f}{s}+%.1f\\,s$', Kp, Kp/Ti, Kp*Td);
            cbPID.Enable = 'on';
            if cbPID.Value
                [yp, up] = simulate(Z(3,1), Z(3,2), Z(3,3));
                hYp.YData = y0 + yp;  hUp.YData = u0 + up;
            end
        else
            lblCrit.Text = sprintf('Kcr = %6s\nPc  = %6s\nωc  = %6s', '—', '—', '—');
            tbl.Data = {'P','—','—','—'; 'PI','—','—','—'; 'PID','—','—','—'};
            eqN1.String = '';  eqN2.String = '';
            cbPID.Enable = 'off';
        end
        showPID = found && cbPID.Value;
        hYp.Visible = showPID;  hUp.Visible = showPID;
        hY.Visible = ~showPID;  hU.Visible = ~showPID;
    end

%% ---------------- Simulation ----------------
    function [y, u] = simulate(Kp, Ti, Td)
        % Closed loop, deviation variables (y = temperature - 40 °C).
        % PID: u = Kp*(e + (1/Ti)*integral(e) + Td*de/dt), derivative taken
        % on the measurement and filtered with Td/10.
        n  = numel(t);
        nd = round(p.delay/dt);
        y = zeros(n,1);  u = zeros(n,1);
        x = [0; 0; 0];                 % [heater; tank; sensor]
        pipe = zeros(n + nd + 1, 1);   % tank temperature travelling in the pipe
        I = 0;  D = 0;  yPrev = 0;
        for k = 1:n
            y(k) = x(3);
            e = r - y(k);
            if Td > 0
                Tf = Td/10;
                D = Tf/(Tf+dt)*D - Kp*Td/(Tf+dt)*(y(k) - yPrev);
            end
            u(k) = Kp*e + I + D;
            if isfinite(Ti), I = I + Kp*dt/Ti*e; end
            yPrev = y(k);
            x = rk4(x, u(k), pipe(k));
            pipe(k + nd + 1) = x(2);
        end
    end

    function x = rk4(x, u, Tpipe)
        k1 = dyn(x, u, Tpipe);
        k2 = dyn(x + dt/2*k1, u, Tpipe);
        k3 = dyn(x + dt/2*k2, u, Tpipe);
        k4 = dyn(x + dt*k3, u, Tpipe);
        x = x + dt/6*(k1 + 2*k2 + 2*k3 + k4);
    end

    function dx = dyn(x, u, Tpipe)
        % energy balances of heater, tank water and sensor
        dx = [ (p.Pmax*u/100 - p.hA*(x(1) - x(2))) / p.Ch
               (p.hA*(x(1) - x(2)) - p.wUA*x(2))   / p.Ct
               (Tpipe - x(3))                      / p.tauS ];
    end

%% ---------------- Oscillation analysis ----------------
    function [ratio, Pc] = analyse(y)
        % ratio = amplitude of the last cycle / amplitude of the cycle before
        ratio = NaN;  Pc = NaN;
        iMax = find(y(2:end-1) > y(1:end-2) & y(2:end-1) >= y(3:end)) + 1;
        iMin = find(y(2:end-1) < y(1:end-2) & y(2:end-1) <= y(3:end)) + 1;
        amp = [];  tPk = [];
        for i = iMax'
            j = iMin(find(iMin > i, 1));           % next minimum
            if isempty(j), break; end
            if y(i) - y(j) < 1e-3, break; end      % oscillation has died out
            amp(end+1) = y(i) - y(j);  tPk(end+1) = t(i); %#ok<AGROW>
        end
        if numel(amp) < 3, return; end
        ratio = amp(end)/amp(end-1);
        Pc = mean(diff(tPk(end-2:end)));
    end

    function s = f(v)
        s = sprintf('%.2f', v);
    end
end

%% ---------------- Empty axes used to typeset equations ----------------
function ax = eqAxes(parent)
ax = uiaxes(parent);
ax.Layout.Column = [1 2];
axis(ax,'off');  ax.XLim = [0 1];  ax.YLim = [0 1];
try, ax.Toolbar.Visible = 'off'; catch, end
try, disableDefaultInteractivity(ax); catch, end
end

%% ---------------- Sketch of the process ----------------
function drawSketch(ax)
hold(ax,'on');  axis(ax,'equal');  axis(ax,'off');
ax.XLim = [0 10];  ax.YLim = [0 4.2];
try, ax.Toolbar.Visible = 'off'; catch, end
try, disableDefaultInteractivity(ax); catch, end
ink = [0.2 0.2 0.2];
rectangle(ax,'Position',[0.2 2.9 1.6 0.2],'FaceColor',[0.3 0.5 0.9],'EdgeColor','none');   % inlet
text(ax,0.2,3.55,'cold','FontSize',9);
rectangle(ax,'Position',[1.8 0.5 2.6 2.9],'FaceColor',[0.85 0.45 0.4],'EdgeColor',ink,'LineWidth',2); % tank
x = linspace(2.2,4.0,11);  plot(ax, x, 0.8 + 0.25*mod(0:10,2), 'Color',[1 0.85 0.1],'LineWidth',3); % heater
text(ax,3.1,2.2,'tank','HorizontalAlignment','center','Color','w','FontWeight','bold');
text(ax,3.1,0.15,'heater  u','HorizontalAlignment','center','FontSize',9);
rectangle(ax,'Position',[4.4 0.9 4.0 0.2],'FaceColor',[0.85 0.45 0.4],'EdgeColor',ink);     % pipe
text(ax,6.4,0.5,'pipe: 30 s delay','HorizontalAlignment','center','FontSize',9);
plot(ax,[8.0 8.0],[1.1 1.9],'Color',ink,'LineWidth',1.5);                                   % sensor
rectangle(ax,'Position',[7.6 1.9 0.8 0.8],'Curvature',[1 1],'FaceColor','w','EdgeColor',ink);
text(ax,8.0,2.3,'TT','HorizontalAlignment','center','FontWeight','bold','FontSize',9);
text(ax,8.6,2.3,'y','FontSize',11,'FontWeight','bold');
end
