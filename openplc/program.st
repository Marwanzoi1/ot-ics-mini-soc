FUNCTION_BLOCK FB_AlarmManager
  VAR_INPUT
    TankLevel : INT;
    Pressure : INT;
    PumpFaultIn : BOOL;
    ValveFaultIn : BOOL;
  END_VAR
  VAR_OUTPUT
    LowLevel : BOOL;
    HighLevel : BOOL;
    HighHighLevel : BOOL;
    HighPressure : BOOL;
    AlarmActive : BOOL;
  END_VAR

  (* ========================================= *)
  (* FB_AlarmManager                           *)
  (* Process alarms and critical conditions    *)
  (* ========================================= *)

  (* Level alarms *)
  LowLevel := TankLevel <= 20;
  HighLevel := TankLevel >= 80;
  HighHighLevel := TankLevel >= 95;

  (* Pressure alarm *)
  HighPressure := Pressure >= 8;

  (* Master alarm *)
  AlarmActive :=
      LowLevel OR
      HighLevel OR
      HighHighLevel OR
      HighPressure OR
      PumpFaultIn OR
      ValveFaultIn;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_ProcessSimulation
  VAR_INPUT
    Enable : BOOL;
    InletValve : BOOL;
    PumpRun : BOOL;
    OutletValve : BOOL;
  END_VAR
  VAR_OUTPUT
    FlowRate : INT;
    Pressure : INT;
  END_VAR
  VAR_IN_OUT
    TankLevel : INT;
  END_VAR
  VAR
    SimTimer : TON;
    TargetFlow : INT := 0;
    TargetPressure : INT := 0;
  END_VAR

  // (* ========================================= *)
  // (* FB_ProcessSimulation                     *)
  // (* Simulated tank, flow and pressure        *)
  // (* ========================================= *)

  // IF Enable THEN

  //     (* Filling path *)
  //     IF InletValve AND PumpRun THEN
  //         IF TankLevel < 100 THEN
  //             TankLevel := TankLevel + 1;
  //         END_IF;

  //         FlowRate := 25;
  //         Pressure := 3;

  //     ELSE
  //         FlowRate := 0;
  //         Pressure := 0;
  //     END_IF;

  //     (* Discharge path *)
  //     IF OutletValve THEN
  //         IF TankLevel > 0 THEN
  //             TankLevel := TankLevel - 2;
  //         END_IF;

  //         FlowRate := 35;
  //         Pressure := 4;
  //     END_IF;

  // ELSE
  //     FlowRate := 0;
  //     Pressure := 0;
  // END_IF;

  // (* Safety clamp *)
  // IF TankLevel > 100 THEN
  //     TankLevel := 100;
  // ELSIF TankLevel < 0 THEN
  //     TankLevel := 0;
  // END_IF;





  (* ========================================= *)
  (* FB_ProcessSimulation V3                   *)
  (* Dynamic water process simulation          *)
  (* ========================================= *)

  (* ----------------------------------------- *)
  (* Determine target flow and pressure        *)
  (* ----------------------------------------- *)

  IF Enable THEN

      IF InletValve AND PumpRun THEN

          TargetFlow := 25;

          IF TankLevel < 30 THEN
              TargetPressure := 2;
          ELSIF TankLevel < 70 THEN
              TargetPressure := 3;
          ELSE
              TargetPressure := 4;
          END_IF;

      ELSIF OutletValve THEN

          IF TankLevel >= 75 THEN
              TargetFlow := 30;
          ELSIF TankLevel >= 50 THEN
              TargetFlow := 24;
          ELSIF TankLevel >= 25 THEN
              TargetFlow := 16;
          ELSIF TankLevel > 0 THEN
              TargetFlow := 8;
          ELSE
              TargetFlow := 0;
          END_IF;

          TargetPressure := 0;

      ELSE

          TargetFlow := 0;
          TargetPressure := 0;

      END_IF;

  ELSE

      TargetFlow := 0;
      TargetPressure := 0;

  END_IF;


  (* ----------------------------------------- *)
  (* Simulation timer                          *)
  (* ----------------------------------------- *)

  SimTimer(
      IN := NOT SimTimer.Q,
      PT := T#1s
  );


  (* ----------------------------------------- *)
  (* Update simulation once per second         *)
  (* ----------------------------------------- *)

  IF SimTimer.Q THEN

      (* Flow ramps toward target *)
      IF FlowRate < TargetFlow THEN
          FlowRate := FlowRate + 5;
          IF FlowRate > TargetFlow THEN
              FlowRate := TargetFlow;
          END_IF;

      ELSIF FlowRate > TargetFlow THEN
          FlowRate := FlowRate - 5;
          IF FlowRate < TargetFlow THEN
              FlowRate := TargetFlow;
          END_IF;
      END_IF;


      (* Pressure ramps toward target *)
      IF Pressure < TargetPressure THEN
          Pressure := Pressure + 1;

      ELSIF Pressure > TargetPressure THEN
          Pressure := Pressure - 1;
      END_IF;


      (* Tank filling *)
      IF Enable AND InletValve AND PumpRun THEN

          IF TankLevel < 100 THEN
              TankLevel := TankLevel + 1;
          END_IF;


      (* Tank discharge *)
      ELSIF Enable AND OutletValve THEN

          IF TankLevel > 0 THEN

              IF TankLevel >= 75 THEN
                  TankLevel := TankLevel - 2;
              ELSE
                  TankLevel := TankLevel - 1;
              END_IF;

          END_IF;

      END_IF;

  END_IF;


  (* ----------------------------------------- *)
  (* Safety clamps                             *)
  (* ----------------------------------------- *)

  IF TankLevel > 100 THEN
      TankLevel := 100;
  ELSIF TankLevel < 0 THEN
      TankLevel := 0;
  END_IF;

  IF FlowRate < 0 THEN
      FlowRate := 0;
  END_IF;

  IF Pressure < 0 THEN
      Pressure := 0;
  END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Pump
  VAR_INPUT
    Command : BOOL;
    Permissive : BOOL;
    Reset : BOOL;
  END_VAR
  VAR_OUTPUT
    RunFeedBack : BOOL;
    Fault : BOOL;
  END_VAR
  VAR
    StartTimer : TON;
  END_VAR

  (* ========================================= *)
  (* FB_Pump                                   *)
  (* Pump command, permissive and fault logic  *)
  (* ========================================= *)

  (* Reset fault *)
  IF Reset THEN
      Fault := FALSE;
  END_IF;

  (* Start delay *)
  StartTimer(
      IN := Command AND Permissive AND NOT Fault,
      PT := T#2s
  );

  (* Normal run *)
  IF StartTimer.Q THEN
      RunFeedback := TRUE;
  ELSIF NOT Command THEN
      RunFeedback := FALSE;
  END_IF;

  (* Fault if commanded without permissive *)
  IF Command AND NOT Permissive THEN
      Fault := TRUE;
      RunFeedback := FALSE;
  END_IF;
END_FUNCTION_BLOCK

PROGRAM main
  VAR_EXTERNAL
    HMI_START : BOOL;
    HMI_STOP : BOOL;
    HMI_RESET : BOOL;
    PROCESS_RUNNING : BOOL;
    ALARM_ACTIVE : BOOL;
    PUMP_FAULT : BOOL;
    VALVE_FAULT : BOOL;
    TANK_LEVEL : INT;
    LEVEL_SP : INT;
    PUMP_RUN : BOOL;
    INLET_VALVE : BOOL;
    AUTO_MODE : BOOL;
    FLOW_RATE : INT;
    PRESSURE : INT;
    OUTLET_VALVE : BOOL;
    PUMP_CMD : BOOL;
    HIGH_PRESSURE : BOOL;
    LOW_LEVEL : BOOL;
    HIGH_LEVEL : BOOL;
    HIGH_HIGH_LEVEL : BOOL;
    INTERLOCK_ACTIVE : BOOL;
  END_VAR
  VAR
    ProcessSim : FB_PROCESSSIMULATION;
    PumpCtrl : FB_PUMP;
    AlarmMgr : FB_ALARMMANAGER;
  END_VAR

  (* ========================================= *)
  (* WATER PROCESS V2 - MAIN CONTROL PROGRAM   *)
  (* ========================================= *)
  (* ========================================= *)
  (* Default operating mode                    *)
  (* Lab operates in automatic mode            *)
  (* ========================================= *)

  AUTO_MODE := TRUE;
  IF LEVEL_SP <= 0 THEN
      LEVEL_SP := 60;
  END_IF;

  (* ========================================= *)
  (* Stage 1: Start / Stop process latch       *)
  (* Operator commands and basic reset         *)
  (* ========================================= *)

  (* STOP has priority over START *)
  IF HMI_STOP THEN
      PROCESS_RUNNING := FALSE;

  ELSIF HMI_START AND NOT INTERLOCK_ACTIVE THEN
      PROCESS_RUNNING := TRUE;
  END_IF;

  (* Valve fault reset - pump fault is reset    *)
  (* inside FB_Pump using HMI_RESET             *)
  IF HMI_RESET THEN
      VALVE_FAULT := FALSE;
  END_IF;

  // (* ========================================= *)
  // (* Stage 2: Automatic tank level control     *)
  // (* Fill / Drain with hysteresis              *)
  // (* ========================================= *)

  // IF PROCESS_RUNNING AND AUTO_MODE THEN

  //     (* Tank too low -> fill *)
  //     IF TANK_LEVEL <= (LEVEL_SP - 5) THEN
  //         INLET_VALVE := TRUE;
  //         OUTLET_VALVE := FALSE;
  //         PUMP_CMD := TRUE;

  //     (* Tank too high -> drain *)
  //     ELSIF TANK_LEVEL >= (LEVEL_SP + 5) THEN
  //         INLET_VALVE := FALSE;
  //         OUTLET_VALVE := TRUE;
  //         PUMP_CMD := FALSE;

  //     (* Inside acceptable band -> hold *)
  //     ELSE
  //         INLET_VALVE := FALSE;
  //         OUTLET_VALVE := FALSE;
  //         PUMP_CMD := FALSE;
  //     END_IF;

  // ELSE
  //     INLET_VALVE := FALSE;
  //     OUTLET_VALVE := FALSE;
  //     PUMP_CMD := FALSE;
  // END_IF;
  (* ========================================= *)
  (* Stage 2: Automatic tank level control     *)
  (* Proper hysteresis around the setpoint     *)
  (* ========================================= *)

  IF PROCESS_RUNNING AND AUTO_MODE THEN

      (* Reached lower limit -> start filling *)
      IF TANK_LEVEL <= (LEVEL_SP - 5) THEN

          INLET_VALVE := TRUE;
          OUTLET_VALVE := FALSE;
          PUMP_CMD := TRUE;


      (* Reached upper limit -> start draining *)
      ELSIF TANK_LEVEL >= (LEVEL_SP + 5) THEN

          INLET_VALVE := FALSE;
          OUTLET_VALVE := TRUE;
          PUMP_CMD := FALSE;

      END_IF;

  ELSE

      INLET_VALVE := FALSE;
      OUTLET_VALVE := FALSE;
      PUMP_CMD := FALSE;

  END_IF;
  (* ========================================= *)
  (* Stage 3: Alarm management                 *)
  (* Level, pressure and equipment fault logic *)
  (* ========================================= *)

  AlarmMgr(
      TankLevel := TANK_LEVEL,
      Pressure := PRESSURE,
      PumpFaultIn := PUMP_FAULT,
      ValveFaultIn := VALVE_FAULT,
      LowLevel => LOW_LEVEL,
      HighLevel => HIGH_LEVEL,
      HighHighLevel => HIGH_HIGH_LEVEL,
      HighPressure => HIGH_PRESSURE,
      AlarmActive => ALARM_ACTIVE
  );


  (* ========================================= *)
  (* Stage 4: Safety interlocks                *)
  (* Critical conditions inhibit operation     *)
  (* ========================================= *)

  INTERLOCK_ACTIVE :=
      HIGH_HIGH_LEVEL OR
      HIGH_PRESSURE OR
      PUMP_FAULT OR
      VALVE_FAULT;


  (* ========================================= *)
  (* Stage 5: Pump control                     *)
  (* Command, permissive, feedback and fault   *)
  (* ========================================= *)

  PumpCtrl(
      Command := PUMP_CMD,
      Permissive := PROCESS_RUNNING AND NOT INTERLOCK_ACTIVE,
      Reset := HMI_RESET,
      RunFeedback => PUMP_RUN,
      Fault => PUMP_FAULT
  );


  (* ========================================= *)
  (* Stage 6: Process simulation               *)
  (* Tank level, flow, pressure and outlet     *)
  (* ========================================= *)

  ProcessSim(
      Enable := PROCESS_RUNNING,
      InletValve := INLET_VALVE,
      PumpRun := PUMP_RUN,
      OutletValve := OUTLET_VALVE,
      TankLevel := TANK_LEVEL,
      FlowRate => FLOW_RATE,
      Pressure => PRESSURE
  );
END_PROGRAM


CONFIGURATION Config0
  VAR_GLOBAL
    HMI_START AT %QX0.0 : BOOL := FALSE;
    HMI_STOP AT %QX0.1 : BOOL := FALSE;
    HMI_RESET AT %QX0.2 : BOOL := FALSE;
    AUTO_MODE AT %QX0.3 : BOOL := TRUE;
    PUMP_RUN AT %QX1.0 : BOOL := FALSE;
    INLET_VALVE AT %QX1.1 : BOOL := FALSE;
    OUTLET_VALVE AT %QX1.2 : BOOL := FALSE;
    PROCESS_RUNNING AT %QX1.3 : BOOL := FALSE;
    PUMP_CMD AT %QX1.4 : BOOL := FALSE;
    LOW_LEVEL AT %QX2.0 : BOOL := FALSE;
    HIGH_LEVEL AT %QX2.1 : BOOL := FALSE;
    HIGH_HIGH_LEVEL AT %QX2.2 : BOOL := FALSE;
    ALARM_ACTIVE AT %QX2.3 : BOOL := FALSE;
    PUMP_FAULT AT %QX2.4 : BOOL := FALSE;
    VALVE_FAULT AT %QX2.5 : BOOL := FALSE;
    HIGH_PRESSURE AT %QX2.6 : BOOL := FALSE;
    INTERLOCK_ACTIVE AT %QX2.7 : BOOL := FALSE;
    TANK_LEVEL AT %QW0 : INT := 30;
    FLOW_RATE AT %QW1 : INT := 0;
    PRESSURE AT %QW2 : INT := 0;
    LEVEL_SP AT %QW3 : INT := 70;
  END_VAR

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#100ms,PRIORITY := 1);
    PROGRAM instance0 WITH task0 : main;
  END_RESOURCE
END_CONFIGURATION
