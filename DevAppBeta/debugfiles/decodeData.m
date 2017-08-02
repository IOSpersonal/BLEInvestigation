%% load data
clc;
clear;
fileID = fopen('MDM-1211_offload.txt','r');
A=fscanf(fileID,'%s');
fclose(fileID);
rawdata = zeros(1,length(A)/2);
for i = 1:length(A)/2
    hex = strcat(A(2*i-1),A(2*i));
    dec = hex2dec(hex);
    rawdata(i) = dec;
end
data = reshape(rawdata,19,length(rawdata)/19)';
data(:,2) = data(:,2) * 256 + data(:,3);
data = sortrows(data,2);
%% decode

