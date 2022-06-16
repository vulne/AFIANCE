clc;
clear all;

%% Iniciacion
% Find a VISA-TCPIP object.
obj1 = instrfind('Type', 'visa-tcpip', 'RsrcName', 'TCPIP0::169.254.69.235::inst0::INSTR', 'Tag', '');
% Create the VISA-TCPIP object if it does not exist
% otherwise use the object that was found.
if isempty(obj1)
    obj1 = visa('RS', 'TCPIP0::169.254.69.235::inst0::INSTR');
else
    fclose(obj1);
    obj1 = obj1(1);
end

% Connect to instrument object, obj1.
fopen(obj1);

% Instrument Configuration and Control

% Communicating with instrument object, obj1.
data1 = query(obj1, '*IDN?');

deviceObj = icdevice('matlab_rszvb_driver.mdd', 'TCPIP::169.254.69.235::INSTR');

% Connect device object to hardware.
connect(deviceObj);

pause(1);
s1 = serialport('COM5', 115200);
flush(s1);


%% Parametros
%VNA
setupName='Medicion';
channel=1;                      
traceName='Trc1PP';
numberOfPoints=201;                 %Cantidad de puntos en el sweep.
singleSweep=0;                      %single=0; cte=1. Single significa que se para de muestrear.
sweepCount=2;                       %Número de sweeps por medicion.
sweepType=0;                        %(lineal frequency sweep=0).
startFrequency=26.5E9;              %Frecuencia inicial medición.
stopFrequency=29.5E9;               %Frecuencia final de medición.
power=0;                            %Potencia de salida. En dbm
inPort=1;                           %Puerto de entrada
outPort=1;                          %Puerto de salida
real_=7;                            %Resultados de Snn real.
imag_=8;                            %Resultados de Snn complejo
channel_Trace=1;                    
timeout=10000;                      %Tiempo máximo aceptable de demora. Si se cumple, entonces hay un error.
window=1;                           
window_Trace=1;
scaleDivisions=5;                   %Divison de escala.
referenceLevel=0;                   %Valor que corta eje X en eje Y.
freq=zeros(numberOfPoints,1);       %Matriz donde se almacenan valores de frecuencia.
s21=zeros(402,1);                   %Matriz que capta cadena de valores desde VNA.

% Sistema de apuntamiento
% Azimuth configuration
az_ini = 0;                         %Valor incial de ángulo azimutal azimutal.
az_step = 45;                       %Paso de ángulo azimutal.
az_end = 360;                       %Valor final de ángulo azimutal.
% Elevation configuration
el_ini = 0;                         %Valor incial de ángulo de elevación.
el_step = 45;                       %Paso de ángulo de elevación
el_end =90;                         %Valor final de ángulo de elevación.


num_meas=1;                         %Cantidad de mediciones por posición (az,el)

meas=zeros(az_end+1,el_end+1,num_meas,numberOfPoints*2);        %Matriz 4 dimenciones

%grados azimut, grados elevación, cantidad de mediciones por punto, número
%de puntos.
%Los valores reales quedan en posiciones impares y los valores complejos en
%las posiciones pares.


% Configuracion mediciones VNA

% Cargar calibración./
groupObj = get(deviceObj, 'Filefilemassstoragecapabilities');
invoke (groupObj, 'SetupRecall', 'C:\Rohde&Schwarz\Nwa\Calibration\RecallSets\s12_1001.zvx')

% Borrar todas las curvas que hayan.
groupObj = get(deviceObj, 'Tracetraceselect');
invoke (groupObj, 'TraceDeleteAll', channel)

% Crear ventana nueva para una curva nueva.
groupObj = get(deviceObj, 'Tracetraceselect');
invoke (groupObj, 'TraceAdd', channel, traceName)
invoke (groupObj, 'TraceAssignDiagramArea', channel, window_Trace, traceName)

% Configurar cantidad de puntos por sweep, tipo de sweep y cantidad de
% sweep a promediar por cada posición.
groupObj = get(deviceObj, 'Channelsweep');
invoke (groupObj, 'SetSweepNumberOfPoints', channel, numberOfPoints)
invoke (groupObj, 'SetSweepSingle', channel, singleSweep)
invoke (groupObj, 'SetSweepCount', channel, sweepCount)

% Configurar a sweep frecuencial y lineal.
groupObj = get(deviceObj, 'Channelsweepsweeptype');
invoke (groupObj, 'SetSweepType', channel, sweepType)

% Configurar frecuencia inicial, final y potencia.
groupObj = get(deviceObj, 'Channelstimulus');
invoke (groupObj, 'SetStartFrequency', channel, startFrequency)
invoke (groupObj, 'SetStopFrequency', channel, stopFrequency)
invoke (groupObj, 'SetPower', channel, power)

% Configurar el Snn que se requiere.
groupObj = get(deviceObj, 'Tracemeasuresparameters');
invoke (groupObj, 'SelectSParameters', channel, traceName, outPort, inPort)


for az = az_ini:az_step*2:az_end        % azimut
  for el = el_ini:el_step:el_end        % elevation
      for medida=1:num_meas             % cantidad de medidas por posición
          tic
         
          % Mover la dirección de apuntamiento a (az,el)
          aux_str = [num2str(az) ',' num2str(el)];
          writeline(s1, aux_str);
          aux_str2=readline(s1);
          
          fprintf('The current pointing direction is:\n%d grades in azimuthn\n%d grades in elevation.\n\n', az, el);
          
          
          % Medicion
          groupObj = get(deviceObj, 'Channelsweep');
          invoke (groupObj, 'SendChannelTriggerWaitOPC', channel, timeout)
          
          % Toma de valores
          groupObj = get(deviceObj, 'Tracetracefunctionstracedata');
          [noofValues, freq] = invoke (groupObj, 'TraceStimulusData', channel_Trace, freq);
          [noofValues, meas(az+1,el+1,medida,:)] = invoke (groupObj, 'TraceResponseData', channel_Trace, 2, s21');
         
          toc
      end
  end
  
  
  az_2 = az+az_step;
  if az_2<az_end
      for el = el_end:-el_step:el_ini
          for medida=1:num_meas
              
              % Mover la dirección de apuntamiento a (az,el)
              aux_str = [num2str(az_2) ',' num2str(el)];
              writeline(s1, aux_str);
              fprintf('The current pointing direction is:\n%d grades in azimuthn\n%d grades in elevation.\n\n', az_2, el);
              pause(2);

              % Medición
              groupObj = get(deviceObj, 'Channelsweep');
              invoke (groupObj, 'SendChannelTriggerWaitOPC', channel, timeout)
          
        	  % Toma de valores
              groupObj = get(deviceObj, 'Tracetracefunctionstracedata');
              [noofValues, freq] = invoke (groupObj, 'TraceStimulusData', channel_Trace, freq);
              [noofValues, meas(az_2+1,el+1,medida,:)] = invoke (groupObj, 'TraceResponseData', channel_Trace, 2, s21');
          end
      
      end
  end

end

export=zeros((az_end+1)*(el_end+1),2+(numberOfPoints*num_meas));

for i=1:361
    export((i-1)*91+1:(i-1)*91+90+1,1)=repmat(i-1,[91,1]);
    export((i-1)*91+1:(i-1)*91+90+1,2)=(0:90)';
end

for m=1:num_meas
    
    for i=1:max(size(export))
        export(i,3+(202*(m-1)):203+(202*(m-1)))=squeeze(meas(export(i,1)+1,export(i,2)+1,m,1:2:noofValues)+1j*meas(export(i,1)+1,export(i,2)+1,m,2:2:noofValues))';
    end
    
end

export(:,1:2)=double(export(:,1:2));

writematrix(export,'dataexport.txt','Delimiter',';');
