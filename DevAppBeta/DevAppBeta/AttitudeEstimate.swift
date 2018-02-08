//
//  AttitudeEstimate.swift
//  Using a QUEST Kalman Filter, with magnetometer data excluded
//  DevAppBeta
//
//  Created by Weihang Liu on 21/7/17.
//  Copyright © 2017 Weihang Liu. All rights reserved.
//

import Foundation
import Accelerate

precedencegroup PowerPrecedence{higherThan: MultiplicationPrecedence}
infix operator ^^ : PowerPrecedence
func ^^ (radix: Double, power: Double) -> Double{
    return Double(pow(radix,power))
}

class AttitudeEstimator: NSObject {
    
    //initial param
    private let NGyroProcess = 0.05
    private let NGyroMeasure = 0.005
    private let NQuatMeasure = 0.005
    private let tau = 0.01
    private let pi = 3.14159265359
    private let naturalLogarithm = 2.718281828459
    //noise matrix
    private var R_Matrix: [Double]
    public var x = [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0]
    private var P_Matrix: [Double]
    
    //observation matrix
    private var H_Matrix = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
    
    private let eye7 = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                       0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                       0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
                       0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
                       0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0,
                       0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0,
                       0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0]
    
    override init(){
        self.R_Matrix = [NGyroProcess^^2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, NGyroProcess^^2, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, NGyroProcess^^2, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, NQuatMeasure^^2, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, NQuatMeasure^^2, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, NQuatMeasure^^2, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, 0.0, NQuatMeasure^^2]
        self.P_Matrix = [naturalLogarithm^^30, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, naturalLogarithm^^30, 0.0, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, naturalLogarithm^^30, 0.0, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, naturalLogarithm^^30, 0.0, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, naturalLogarithm^^30, 0.0, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, naturalLogarithm^^30, 0.0,
                         0.0, 0.0, 0.0, 0.0, 0.0, 0.0, naturalLogarithm^^30]
        super.init();
    }
    
    func calculateQuaternionWithData(accx: Double, accy: Double, accz: Double) -> [Double]{
        let constDen = (accx^^2 + accy^^2 + accz^^2).squareRoot()
        let accxNorm = accx/constDen
        let accyNorm = accy/constDen
        let acczNorm = accz/constDen
        var q = [Double]()
        if acczNorm > 0{
            q.append(((acczNorm + 1)*2).squareRoot())
            q.append(-accyNorm/(2*(acczNorm+1)).squareRoot())
            q.append(accxNorm/(2*(acczNorm+1)).squareRoot())
            q.append(0.0)
        }
        else{
            q.append(-accyNorm/(2*(1-acczNorm)).squareRoot())
            q.append(((1-acczNorm)*2).squareRoot())
            q.append(0.0)
            q.append(accxNorm/(2*(1-acczNorm)).squareRoot())
        }
        return q
    }
    
    func invert(matrix : [Double]) -> [Double] {
        //calculate inverse of matrix
        var inMatrix = matrix
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Double](repeating: 0.0, count: Int(N))
        var error : __CLPK_integer = 0
        
        withUnsafeMutablePointer(to: &N) {
            dgetrf_($0, $0, &inMatrix, $0, &pivots, &error)
            dgetri_($0, &inMatrix, $0, &pivots, &workspace, $0, &error)
        }
        return inMatrix
    }
    
    func EKFProcessStepWithData(accx: Double, accy: Double, accz: Double, gyrox: Double, gyroy: Double, gyroz: Double, deltaT: Double) -> [Double]{
        //perform an attitude estimation step
        let decay = self.naturalLogarithm ^^ (-deltaT/self.tau)
        let t = decay/2.0
        //state transition matrix
        let F_Matrix = [decay, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, decay, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, decay, 0.0, 0.0, 0.0, 0.0,
                        -x[4]*t, -x[5]*t, -x[6]*t, 1.0, -x[0]*t, -x[1]*t, -x[2]*t,
                         x[3]*t, -x[6]*t,  x[5]*t, x[0]*t, 1.0,   x[2]*t, -x[1]*t,
                         x[6]*t,  x[3]*t, -x[4]*t, x[1]*t, -x[2]*t, 1.0,   x[0]*t,
                        -x[5]*t,  x[4]*t,  x[3]*t, x[2]*t,  x[1]*t, -x[0]*t, 1.0]
        var F_Transpose = Array.init(repeating: 0.0, count: 49)
        vDSP_mtransD(F_Matrix,1,&F_Transpose,1,7,7)
        let q = self.calculateQuaternionWithData(accx: accx, accy: accy, accz: accz)
        let z_vec = [gyrox*pi/180, -gyroy*pi/180, gyroz*pi/180, q[0], q[1], q[2], q[3]]
        let GyroProcessNoise = self.NGyroProcess^^2*(1-decay^^2)/(2*self.tau)
        let Q_Matrix = [GyroProcessNoise, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, GyroProcessNoise, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, GyroProcessNoise, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let xp4 = x[3] - 0.5*t*(x[0]*x[4] + x[1]*x[5] + x[2]*x[6])
        let xp5 = x[4] + 0.5*t*(x[0]*x[3] - x[1]*x[6] + x[2]*x[5])
        let xp6 = x[5] + 0.5*t*(x[0]*x[6] + x[1]*x[3] - x[2]*x[4])
        let xp7 = x[6] + 0.5*t*(-x[0]*x[5] + x[1]*x[4] + x[2]*x[3])
        let xPrior_vec = [decay*x[0],
                          decay*x[1],
                          decay*x[2],
                          xp4,
                          xp5,
                          xp6,
                          xp7]
        //state transition P_prior = FPF' + Q
        var tempProduct1 = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(F_Matrix,1,self.P_Matrix,1,&tempProduct1,1,7,7,7)
        var tempProduct2 = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(tempProduct1,1,F_Transpose,1,&tempProduct2,1,7,7,7)
        var PPrior_Matrix = Array.init(repeating: 0.0, count: 49)
        vDSP_vaddD(tempProduct2,1,Q_Matrix,1,&PPrior_Matrix, 1, vDSP_Length(tempProduct2.count))
        //update status
        var tempProduct3 = Array.init(repeating: 0.0, count: 7)
        vDSP_mmulD(H_Matrix,1,xPrior_vec,1,&tempProduct3,1,7,1,7)
        var tempProduct4 = Array.init(repeating: 0.0, count: 7)
        var minusOne = -1.0
        vDSP_vsmulD(tempProduct3,1,&minusOne,&tempProduct4,1,vDSP_Length(tempProduct3.count))
        var y_vec = Array.init(repeating: 0.0, count: 7)
        vDSP_vaddD(z_vec,1,tempProduct4,1,&y_vec,1,vDSP_Length(z_vec.count))
        var tempProduct5 = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(H_Matrix,1,PPrior_Matrix,1,&tempProduct5,1,7,7,7)
        var H_Transpose = Array.init(repeating: 0.0, count: 49)
        vDSP_mtransD(H_Matrix,1,&H_Transpose,1,7,7)
        var tempProduct6 = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(tempProduct5,1,H_Transpose,1,&tempProduct6,1,7,7,7)
        var S_Matrix = Array.init(repeating: 0.0, count: 49)
        vDSP_vaddD(tempProduct6,1,self.R_Matrix,1,&S_Matrix,1,vDSP_Length(tempProduct6.count))
        var tempProduct7 = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(PPrior_Matrix,1,H_Transpose,1,&tempProduct7,1,7,7,7)
        let S_Inverse = self.invert(matrix: S_Matrix)
        var K_Matrix = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(tempProduct7,1,S_Inverse,1,&K_Matrix,1,7,7,7)
        var tempProduct8 = Array.init(repeating: 0.0, count: 7)
        vDSP_mmulD(K_Matrix,1,y_vec,1,&tempProduct8,1,7,1,7)
        vDSP_vaddD(xPrior_vec,1,tempProduct8,1,&self.x,1,vDSP_Length(xPrior_vec.count))
        var tempProduct9 = Array.init(repeating: 0.0, count: 49)
        vDSP_mmulD(K_Matrix,1,H_Matrix,1,&tempProduct9,1,7,7,7)
        var tempProduct10 = Array.init(repeating: 0.0, count: 49)
        vDSP_vsmulD(tempProduct9,1,&minusOne,&tempProduct10,1,vDSP_Length(tempProduct9.count))
        var tempProduct11 = Array.init(repeating: 0.0, count: 49)
        vDSP_vaddD(self.eye7,1,tempProduct10,1,&tempProduct11,1,vDSP_Length(self.eye7.count))
        vDSP_mmulD(tempProduct11,1,PPrior_Matrix,1,&self.P_Matrix,1,7,7,7)
        //normalise and output
        let normFac = 1/((x[3]^^2 + x[4]^^2 + x[5]^^2 + x[6]^^2).squareRoot())
        x[3] = x[3] * normFac
        x[4] = x[4] * normFac
        x[5] = x[5] * normFac
        x[6] = x[6] * normFac
        let quatOut = [x[3], x[4], x[5], x[6]]
        return quatOut
    }
}
