clear all; clc; close all;

sigma = 5.46;
gamma_var = 20.0;
C = 1.2; 
D = 0.2083; 
z_plane = 87.3;

% 2. Simulation Time and Initial Conditions
t_start = 0;
t_end = 150; 
t_transient = 50; % Time to discard initial transient behavior
initial_conditions = [0.1; 0.1; 0.1]; 

% 3. ODE Solver Options (Event Function ADDED)
% Reason: To accurately detect intersection events
options = odeset('RelTol', 1e-6, 'AbsTol', 1e-9, ...
                 'Events', @(t, Y) poincare_event(t, Y, z_plane));

% 4. Numerical Integration using ode45
% te: event times, ye: state [x, y, z] at events
[t, state_vars, te, ye, ie] = ode45(@(t, Y) pmsm_dynamics(t, Y, sigma, gamma_var, C, D), ...
                                    [t_start t_end], initial_conditions, options);

% 5. Variable Separation
x = state_vars(:, 1); % Dimensionless angular velocity
y = state_vars(:, 2); % Dimensionless q-axis current
z = state_vars(:, 3); % Dimensionless d-axis current

% 6. Removing Transient Phase (Time Series)
valid_idx = find(t > t_transient);
t_plot = t(valid_idx);
x_plot = x(valid_idx);
y_plot = y(valid_idx);
z_plot = z(valid_idx);

% --- Removing transient events ---
valid_event_idx = find(te > t_transient);
if ~isempty(ye)
    x_poincare = ye(valid_event_idx, 1);
    y_poincare = ye(valid_event_idx, 2);
else
    x_poincare = []; y_poincare = [];
end

% =========================================================
% --- Visualization Section ---
% =========================================================

% Time Series Plot (PDF-friendly: white background, black data)
figure('Color', 'w');
subplot(3,1,1); plot(t_plot, x_plot, 'k', 'LineWidth', 1); ylabel('Speed (x)'); title('PMSM Time Series Analysis (Clean Model)'); grid on;
subplot(3,1,2); plot(t_plot, y_plot, 'k', 'LineWidth', 1); ylabel('q-axis Current (y)'); grid on;
subplot(3,1,3); plot(t_plot, z_plot, 'k', 'LineWidth', 1); xlabel('Dimensionless Time (\tau)'); ylabel('d-axis Current (z)'); grid on;

% 3D Phase Space Plot (PDF-friendly: black trajectory on white background)
figure('Color', 'w');
plot3(x_plot, y_plot, z_plot, 'k', 'LineWidth', 0.5);
hold on;
grid on; 
xlabel('Speed (x)'); ylabel('q-axis Current (y)'); zlabel('d-axis Current (z)');
title(['3D Phase Space and Poincare Plane (z = ', num2str(z_plane), ')']);
view(45, 30);

% Poincare Map (CRITICAL FIX: was 'w.' which is invisible on white background)
figure('Color', 'w');
plot(x_poincare, y_poincare, 'k.', 'MarkerSize', 6);
grid on;
xlabel('Speed (x)'); ylabel('q-axis Current (y)');
title(sprintf('Poincare Section (Event Method, z = %.1f)', z_plane));

% =========================================================
% --- Period Doubling Bifurcation Analysis ---
% =========================================================
gamma_range = linspace(0, 40, 500); 
x_max_bif = []; 
z_max_bif = [];
tspan_bif = [0 200]; 
current_ic = [0.1; 0.1; 0.1];

for i = 1:length(gamma_range)
    g_val = gamma_range(i);
    
    [t_bif, Y_bif] = ode45(@(t, Y) pmsm_dynamics(t, Y, sigma, g_val, C, D), tspan_bif, current_ic);
    
    current_ic = Y_bif(end, :)';
    
    num_steps = length(t_bif);
    transient_steps = round(num_steps * 0.3);
    
    x_steady = Y_bif(transient_steps:end, 1); 
    z_steady = Y_bif(transient_steps:end, 3);
    
    [pksx, ~] = findpeaks(x_steady);
    [pksz, ~] = findpeaks(z_steady);
    
    if ~isempty(pksx)
        x_max_bif = [x_max_bif; g_val * ones(length(pksx), 1), pksx];
    end
    
    if ~isempty(pksz)
        z_max_bif = [z_max_bif; g_val * ones(length(pksz), 1), pksz];
    end
end

% z-axis bifurcation plot
figure('Color', 'w');
plot(z_max_bif(:,1), z_max_bif(:,2), '.k', 'MarkerSize', 1.5);
grid on;
xlabel('Control Parameter \gamma (gamma\_var)');
ylabel('z (d-axis Current) Local Maxima');
title('PMSM Bifurcation Diagram (z-axis analysis)');

% x-axis bifurcation plot
figure('Color', 'w');
plot(x_max_bif(:,1), x_max_bif(:,2), '.k', 'MarkerSize', 1.5);
xlabel('Parameter \gamma (gamma\_var)');
ylabel('x (Speed) Local Maxima');
title('PMSM Period-Doubling Bifurcation Diagram');
grid on;

% =========================================================
% --- Multi-Parameter Dynamical Regimes (Visual Verification) ---
% =========================================================
gamma_list  = [5.0, 11.0, 15.0, 20.0];
labels_list = {'Stable spiral (pre-bifurcation)', ...
               'Limit cycle (Hopf regime)', ...
               'Onset of chaos', ...
               'Fully developed chaos'};

% --- Time series subplot for multiple gamma ---
figure('Color', 'w');
for k = 1:length(gamma_list)
    g_k = gamma_list(k);
    [t_k, Y_k] = ode45(@(t, Y) pmsm_dynamics(t, Y, sigma, g_k, C, D), ...
                      [0 150], initial_conditions, ...
                      odeset('RelTol', 1e-6, 'AbsTol', 1e-9));
    valid_k = t_k > t_transient;
    subplot(length(gamma_list), 1, k);
    plot(t_k(valid_k), Y_k(valid_k, 1), 'k', 'LineWidth', 0.6);
    ylabel('x(t)');
    title(sprintf('\\gamma = %.1f  --  %s', g_k, labels_list{k}));
    grid on;
    if k == length(gamma_list)
        xlabel('Dimensionless Time (\tau)');
    end
end

% --- Phase space (x-y projection) for multiple gamma ---
figure('Color', 'w');
for k = 1:length(gamma_list)
    g_k = gamma_list(k);
    [t_k, Y_k] = ode45(@(t, Y) pmsm_dynamics(t, Y, sigma, g_k, C, D), ...
                      [0 200], initial_conditions, ...
                      odeset('RelTol', 1e-6, 'AbsTol', 1e-9));
    valid_k = t_k > 60; 
    subplot(2, 2, k);
    plot(Y_k(valid_k, 1), Y_k(valid_k, 2), 'k', 'LineWidth', 0.4);
    xlabel('Speed (x)'); ylabel('q-axis Current (y)');
    title(sprintf('\\gamma = %.1f  --  %s', g_k, labels_list{k}));
    grid on;
end

% =========================================================
% --- Full Lyapunov Exponent Analysis (Benettin Algorithm) ---
% =========================================================
dt_lyap = 0.01;         
t_lyap_end = 10000;      
n_steps_lyap = t_lyap_end / dt_lyap;
n_dim = 3;              
Y_lyap = initial_conditions; 
Q_0 = eye(n_dim);       
Y0_ext = [Y_lyap; reshape(Q_0, n_dim^2, 1)]; 

lyap_sum = zeros(n_dim, 1);
lce_vals = zeros(n_steps_lyap, n_dim);
time_vals = zeros(n_steps_lyap, 1);

for i = 1:n_steps_lyap
    k1 = extended_pmsm(0, Y0_ext, sigma, gamma_var, C, D);
    k2 = extended_pmsm(0, Y0_ext + 0.5*dt_lyap*k1, sigma, gamma_var, C, D);
    k3 = extended_pmsm(0, Y0_ext + 0.5*dt_lyap*k2, sigma, gamma_var, C, D);
    k4 = extended_pmsm(0, Y0_ext + dt_lyap*k3, sigma, gamma_var, C, D);
    
    Y_end = Y0_ext + (dt_lyap/6)*(k1 + 2*k2 + 2*k3 + k4);
    
    x_next = Y_end(1:n_dim);
    Q_next = reshape(Y_end(n_dim+1:end), n_dim, n_dim); 
    
    [Q_orth, R] = qr(Q_next); 
    
    lyap_sum = lyap_sum + log(abs(diag(R))); 
    
    lce_vals(i, :) = lyap_sum / (i * dt_lyap);
    time_vals(i) = i * dt_lyap;
    
    Y0_ext = [x_next; reshape(Q_orth, n_dim^2, 1)];
end

% --- Lyapunov plot ---
figure('Color', 'w');
plot(time_vals, lce_vals(:,1), 'k-',  'LineWidth', 1.5); hold on;
plot(time_vals, lce_vals(:,2), 'k--', 'LineWidth', 1.5);
plot(time_vals, lce_vals(:,3), 'k:',  'LineWidth', 1.5);
xlabel('Time'); ylabel('Lyapunov Exponents');
title('PMSM Full Lyapunov Spectrum (Unforced Model)');
grid on;
legend('\lambda_1', '\lambda_2', '\lambda_3', 'Location', 'best');

fprintf('Estimated Maximum Lyapunov Exponent (L1): %.4f\n', lce_vals(end, 1));
fprintf('Estimated Lyapunov Exponents (L1, L2, L3): %.4f, %.4f, %.4f\n', ...
        lce_vals(end, 1), lce_vals(end, 2), lce_vals(end, 3));
fprintf('Sum of Lyapunov Exponents (should be negative for dissipative system): %.4f\n', sum(lce_vals(end, :)));

% =========================================================
% --- Stability Analysis (Equilibrium Points & Eigenvalues) ---
% =========================================================
fprintf('\n=========================================================\n');
fprintf('--- STABILITY ANALYSIS (PHYSICS-PRESERVING MODEL) ---\n');
fprintf('=========================================================\n');

syms x_sym y_sym z_sym
f1 = sigma * (y_sym - x_sym);
f2 = gamma_var * x_sym - y_sym - D * x_sym * z_sym;
f3 = C * x_sym * y_sym - z_sym;

J_sym = jacobian([f1, f2, f3], [x_sym, y_sym, z_sym]);
eqns = [f1 == 0, f2 == 0, f3 == 0];
sol = solve(eqns, [x_sym, y_sym, z_sym]);
pts = double([sol.x_sym, sol.y_sym, sol.z_sym]);

fprintf('--- All Fixed Points Analysis ---\n\n');
for i = 1:size(pts, 1)
    current_pt = pts(i, :);
    fprintf('Point %d: (x=%.3f, y=%.3f, z=%.3f)\n', i, current_pt(1), current_pt(2), current_pt(3));
    
    J_at_pt = subs(J_sym, [x_sym, y_sym, z_sym], current_pt);
    ev = double(eig(J_at_pt));
    
    fprintf('Eigenvalues:\n');
    disp(ev);
    
    real_parts = real(ev);
    imag_parts = imag(ev);
    
    if all(real_parts < 0)
        if any(imag_parts ~= 0)
            fprintf('Result: Stable Spiral\n');
        else
            fprintf('Result: Stable Node\n');
        end
    elseif any(real_parts > 0)
        if any(imag_parts ~= 0)
            if any(real_parts < 0)
                fprintf('Result: Unstable Spiral (Saddle-Focus)\n');
            else
                fprintf('Result: Unstable Spiral\n');
            end
        else
            fprintf('Result: Unstable Node / Saddle Point\n');
        end
    else
        fprintf('Result: Marginal/Neutral Stability\n');
    end
    fprintf('-------------------------------------------\n');
end

% =========================================================
% --- Master-Slave Synchronization via PID Control ---
% =========================================================
Kp_pid = 8;
Kd_pid = 4;
Ki_pid = 1;

X0_pid = [ 0.1;  0.1;  0.1;    
          -0.5;  0.3;  0.2;    
           0.0];               
tspan_pid = [0 50];
[t_pid, X_pid] = ode45(@(t, X) pmsm_pid_sync(t, X, sigma, gamma_var, C, D, ...
                                              Kp_pid, Kd_pid, Ki_pid), ...
                       tspan_pid, X0_pid, ...
                       odeset('RelTol', 1e-7, 'AbsTol', 1e-10));

xm_pid = X_pid(:,1); ym_pid = X_pid(:,2); zm_pid = X_pid(:,3);
xs_pid = X_pid(:,4); ys_pid = X_pid(:,5); zs_pid = X_pid(:,6);
w_pid  = X_pid(:,7);

e1_pid = xm_pid - xs_pid;
e2_pid = ym_pid - ys_pid;
e3_pid = zm_pid - zs_pid;

u_pid = Kp_pid*e1_pid + Kd_pid*e2_pid + Ki_pid*w_pid;

% --- Plot 1: Master vs Slave states ---
figure('Color', 'w');
subplot(3,1,1);
plot(t_pid, xm_pid, 'k-',  'LineWidth', 1); hold on;
plot(t_pid, xs_pid, 'k--', 'LineWidth', 1);
ylabel('Speed (x)'); legend('Master x_m', 'Slave x_s'); grid on;
title('PMSM Master-Slave Synchronization via PID Control');

subplot(3,1,2);
plot(t_pid, ym_pid, 'k-',  'LineWidth', 1); hold on;
plot(t_pid, ys_pid, 'k--', 'LineWidth', 1);
ylabel('q-axis Current (y)'); legend('Master y_m', 'Slave y_s'); grid on;

subplot(3,1,3);
plot(t_pid, zm_pid, 'k-',  'LineWidth', 1); hold on;
plot(t_pid, zs_pid, 'k--', 'LineWidth', 1);
ylabel('d-axis Current (z)'); xlabel('Dimensionless Time (\tau)');
legend('Master z_m', 'Slave z_s'); grid on;

% --- Plot 2: Synchronization errors ---
figure('Color', 'w');
plot(t_pid, e1_pid, 'k-',  'LineWidth', 1); hold on;
plot(t_pid, e2_pid, 'k--', 'LineWidth', 1);
plot(t_pid, e3_pid, 'k:',  'LineWidth', 1);
xlabel('Dimensionless Time (\tau)'); ylabel('Synchronization Error');
title('Synchronization Errors Decay to Zero');
legend('e_1 = x_m - x_s', 'e_2 = y_m - y_s', 'e_3 = z_m - z_s');
grid on;

% --- Plot 3: Control signal ---
figure('Color', 'w');
plot(t_pid, u_pid, 'k-', 'LineWidth', 0.8);
xlabel('Dimensionless Time (\tau)'); ylabel('Control input u(t)');
title('PID Control Signal (Bounded After Transient)');
grid on;

% --- Plot 4: Phase portraits comparison ---
figure('Color', 'w');
plot(xm_pid, ym_pid, 'k-',  'LineWidth', 0.5); hold on;
plot(xs_pid, ys_pid, 'r--', 'LineWidth', 0.5);
xlabel('Speed (x)'); ylabel('q-axis Current (y)');
title('Phase Portraits: Master vs Slave (Full Trajectory)');
legend('Master', 'Slave'); grid on;

fprintf('\n--- PID Routh-Hurwitz check (worst-case linearization) ---\n');
fprintf('Kp = %.2f, Kd = %.2f, Ki = %.2f\n', Kp_pid, Kd_pid, Ki_pid);
fprintf('Required: Kp + Kd > gamma - 1 = %.2f\n', gamma_var - 1);
fprintf('Actual  : Kp + Kd = %.2f\n', Kp_pid + Kd_pid);
fprintf('Note: Worst-case condition may fail; practical synchronization\n');
fprintf('      can still occur due to bounded chaotic attractor.\n');

% =========================================================
% --- Direct Speed Stabilization via PI-D Controller ---
% =========================================================
fprintf('\n--- Direct Speed Stabilization (PI-D) ---\n');
target_speed = 3;   % Reference speed (x_ref = 3) -> ~807 RPM
X0_speed = [0.1; 0.1; 0.1; 0]; % State: [x; y; z; w], w is integral of error
tspan_speed = [0 100];

% Solve ODE
[t_speed, X_speed] = ode45(@(t, X) pmsm_target_control(t, X, sigma, gamma_var, C, D, target_speed), ...
    tspan_speed, X0_speed, odeset('RelTol', 1e-6, 'AbsTol', 1e-9));

% Extract Variables
x_sp = X_speed(:,1); 
y_sp = X_speed(:,2); 
z_sp = X_speed(:,3);
error_signal = target_speed - x_sp;

% --- Plot 1: Time Series (Speed, Currents, Error) ---
figure('Color', 'w', 'Position', [100, 100, 800, 800]);
subplot(4,1,1);
plot(t_speed, x_sp, 'k', 'LineWidth', 1); hold on;
xline(30, 'r--', 'LineWidth', 1.5);
yline(target_speed, 'b-.', 'LineWidth', 1.5);
ylabel('Speed (x)');
title(['Motor Speed Stabilization: Target x_{ref} = ', num2str(target_speed)]);
legend('Actual Speed', 'Controller Activation', 'Target Speed', 'Location', 'best');
grid on;

subplot(4,1,2);
plot(t_speed, y_sp, 'k', 'LineWidth', 1); hold on;
xline(30, 'r--', 'LineWidth', 1.5);
ylabel('q-axis Current (y)'); grid on;

subplot(4,1,3);
plot(t_speed, z_sp, 'k', 'LineWidth', 1); hold on;
xline(30, 'r--', 'LineWidth', 1.5);
ylabel('d-axis Current (z)'); grid on;

subplot(4,1,4);
plot(t_speed, error_signal, 'k', 'LineWidth', 1.5); hold on;
xline(30, 'r--', 'LineWidth', 1.5); 
yline(0, 'k-', 'LineWidth', 1);
xlabel('Dimensionless Time (\tau)'); ylabel('Error (e = x_{ref} - x)');
title('Tracking Error (Eliminated after t=30)'); grid on;

% --- Plot 2: Phase Space Comparison (Before vs After) ---
figure('Color', 'w', 'Position', [150, 150, 1000, 450]);
idx_old = t_speed < 30;
subplot(1,2,1);
plot3(x_sp(idx_old), y_sp(idx_old), z_sp(idx_old), 'k', 'LineWidth', 0.5);
xlabel('Speed (x)'); ylabel('q-axis Current (y)'); zlabel('d-axis Current (z)');
title('Phase Space (t < 30) - Chaotic Regime'); 
grid on; view(45, 30);

idx_new = t_speed >= 30;
subplot(1,2,2);
plot3(x_sp(idx_new), y_sp(idx_new), z_sp(idx_new), 'k', 'LineWidth', 1.5);
xlabel('Speed (x)'); ylabel('q-axis Current (y)'); zlabel('d-axis Current (z)');
title('Phase Space (t \geq 30) - Stabilized to Target'); 
grid on; view(45, 30);

% =========================================================
% --- Export Figures to PDF ---
% =========================================================
figHandles = findobj('Type', 'figure');
for i = 1:length(figHandles)
    exportgraphics(figHandles(i), ['Grafik_', num2str(i), '.pdf'], 'ContentType', 'vector');
end

% =========================================================
% --- Functions ---
% =========================================================

function dYdt = pmsm_dynamics(~, Y, sigma, gamma_var, C, D)
    dYdt = zeros(3,1);
    dYdt(1) = sigma * (Y(2) - Y(1));
    dYdt(2) = gamma_var * Y(1) - Y(2) - D * Y(1) * Y(3);
    dYdt(3) = C * Y(1) * Y(2) - Y(3);
end

function [value, isterminal, direction] = poincare_event(~, Y, z_plane)
    value = Y(3) - z_plane; 
    isterminal = 0;         
    direction = 1;          
end

function dYdt_ext = extended_pmsm(~, Y, sigma, gamma_var, C, D)
    n = 3;
    x = Y(1:n);                     
    Q = reshape(Y(n+1:end), n, n);  
    
    dx = zeros(n, 1);
    dx(1) = sigma * (x(2) - x(1));
    dx(2) = gamma_var * x(1) - x(2) - D * x(1) * x(3);
    dx(3) = C * x(1) * x(2) - x(3);
    
    J = [-sigma,             sigma,       0;
          gamma_var - D*x(3), -1,          -D*x(1);
          C*x(2),            C*x(1),      -1];
          
    dQ = J * Q;
    
    dYdt_ext = [dx; reshape(dQ, n^2, 1)];
end

function dX = pmsm_pid_sync(t, X, sigma, gamma_var, C, D, Kp, Kd, Ki)
    xm = X(1); ym = X(2); zm = X(3);
    xs = X(4); ys = X(5); zs = X(6);
    w  = X(7);
    
    e1 = xm - xs;
    e2 = ym - ys;
    
    u = Kp*e1 + Kd*e2 + Ki*w;
    
    dxm = sigma * (ym - xm);
    dym = gamma_var * xm - ym - D * xm * zm;
    dzm = C * xm * ym - zm;
    
    dxs = sigma * (ys - xs);
    dys = gamma_var * xs - ys - D * xs * zs + u;
    dzs = C * xs * ys - zs;
    
    dw = e1;
    dX = [dxm; dym; dzm; dxs; dys; dzs; dw];
end

function dX = pmsm_target_control(t, X, sigma, gamma_var, C, D, target_speed)
    x = X(1);
    y = X(2);
    z = X(3);
    w = X(4); 
    
    e = target_speed - x;
    
    if t < 30
        u = 0;
        dw = 0; 
    else
        Kp = 20; 
        Ki = 15; 
        Kd = 2;  
        
        u = Kp * e + Ki * w - Kd * y;
        dw = e;
    end
    
    dx = sigma * (y - x);
    dy = gamma_var * x - y - D * x * z + u;
    dz = C * x * y - z;
    dX = [dx; dy; dz; dw];
end
