# KON314 – Ziegler–Nichols Tuning Lab (Student Guide)

In this lab you tune a PID controller for a real-world process with the **Ziegler–Nichols closed-loop (critical gain) method**.

## How to run it

Put `ZieglerNicholsLab.m` in your MATLAB folder and type:

```matlab
ZieglerNicholsLab
```

You need MATLAB R2024b or newer. No toolboxes are required.

## The system

A 20 L water tank is heated by a 10 kW electric heater while cold water flows through it. The temperature sensor (TT) sits at the end of an outlet pipe, so it measures the water about 30 s after it leaves the tank.

- **Input u [%]:** heater power
- **Output y [°C]:** measured water temperature

The app shows the plant transfer function:

$$G(s)=\frac{Y(s)}{U(s)}=\frac{0.564\,e^{-30s}}{(508.5s+1)(37.1s+1)(15s+1)}$$

The factor $e^{-30s}$ is the pipe's transport delay. It adds phase lag at every frequency, so a high enough gain makes the loop oscillate.

The reference is a 1 °C step, from 40 °C to 41 °C.

## Procedure

1. **Start with P-only control** (u = K·e) at a small gain K.
2. **Increase K slowly** with the slider or the arrow buttons (step 0.1). The plots update immediately. Watch the status message:

   | Status | Meaning | What to do |
   |---|---|---|
   | Decaying | oscillation dies out | increase K |
   | Growing | oscillation grows | decrease K |
   | **Sustained oscillation** | constant amplitude | **K = Kcr** |

3. **Read the critical values.** When the oscillation is sustained, the app shows
   - the critical gain **Kcr**
   - the period of the oscillation **Pc**
   - the critical frequency **ωc = 2π / Pc**
4. **Read the Ziegler–Nichols table:**

   | Controller | Kp | Ti | Td |
   |---|---|---|---|
   | P   | 0.5 Kcr  | –        | –      |
   | PI  | 0.45 Kcr | Pc / 1.2 | –      |
   | PID | 0.6 Kcr  | Pc / 2   | Pc / 8 |

5. **Check the PID.** Tick *Show the closed-loop response with ZN-PID* to see how the system responds with these gains.

## The PID controller

The same controller can be written in two equivalent forms:

$$C(s)=K_p\left(1+\frac{1}{T_i s}+T_d s\right)=K_p+\frac{K_i}{s}+K_d s$$

$$K_i=\frac{K_p}{T_i}, \qquad K_d=K_p\,T_d$$

For the ZN-PID the app writes out both forms with numbers.

> **Note:** As in real controllers, the simulation filters the derivative term (time constant Td/10) and applies it to the measurement instead of the error. This avoids a large spike in u when the reference steps.

## Questions

1. Report Kcr, Pc and ωc. How did you decide that the oscillation was "sustained"?
2. Calculate the P, PI and PID gains by hand from the ZN table and check them against the app. Write your PID in both forms (Kp, Ti, Td) and (Kp, Ki, Kd).
3. At K = Kcr the closed loop is on the stability boundary. What is the phase of G(jωc), and what is the magnitude |G(jωc)|? Use G(s) to verify your answer.
4. Look at the ZN-PID response. Estimate the overshoot. Is it acceptable for a water heater? Ziegler–Nichols aimed for a *quarter-amplitude decay*. What does that mean?
5. What would happen to Kcr if the pipe were longer (larger delay)? Explain using the phase of $e^{-j\omega L}$.
