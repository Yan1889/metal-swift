//
//  Lexer.swift
//  plotter-3d
//
//  Created by Yan Amin on 20.06.26.
//

class Lexer {
    private var tokens = Array<Token>()
    private var error = false
    
    private let str: [Character]
    private var idx = 0
    
    public enum Token: Equatable {
        case NUMBER(Float)
        case X
        case Z
        case LP
        case RP
        case ADD
        case SUB
        case MUL
        case DIV
    }
    
    public static func tokenize(_ s: String) -> [Token]? {
        let l = Lexer(s)
        return l.error ? nil : l.tokens
    }
    
    init(_ s: String) {
        str = Array(s)
        lex()
    }
    
    private func lex() {
        while idx < str.count {
            let c = str[idx]
            if c == " " {
                idx += 1
                continue
            }
            
            switch c {
            case "x": tokens.append(.X)
            case "z": tokens.append(.Z)
            case "(": tokens.append(.LP)
            case ")": tokens.append(.RP)
            case "+": tokens.append(.ADD)
            case "-": tokens.append(.SUB)
            case "*": tokens.append(.MUL)
            case "/": tokens.append(.DIV)
            case "0" ... "9":
                lex_number()
                continue
                
            default: error = true
            }
            
            idx += 1
        }
    }
    
    private func lex_number() {
        var num = Float(0)
        
        while idx < str.count {
            let c = str[idx]
            
            switch c {
            case "0" ... "9": num = num * 10.0 + charToFloat(c)
            default:
                tokens.append(.NUMBER(num))
                return
            }
            
            idx += 1
        }
        
        tokens.append(.NUMBER(num))
    }
    
    
    private func charToFloat(_ c: Character) -> Float {
        Float(c.asciiValue! - Character("0").asciiValue!)
    }
}
