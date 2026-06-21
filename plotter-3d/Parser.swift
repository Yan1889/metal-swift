//
//  Parser.swift
//  plotter-3d
//
//  Created by Yan Amin on 20.06.26.
//

class Parser {
    private let tokens: [Lexer.Token]
    private var idx: Int = 0
    private var exp: Exp?
    
    public indirect enum Exp {
        case Num(Float)
        case X
        case Z
        case Add(Exp, Exp)
        case Sub(Exp, Exp)
        case Mul(Exp, Exp)
        case Div(Exp, Exp)
    }
    
    public static func parse(_ tokens: [Lexer.Token]) -> Exp? {
        let p = Parser(tokens)
        return p.idx < tokens.count ? nil : p.exp
    }
    
    init(_ tokens: [Lexer.Token]) {
        self.tokens = tokens
        
        exp = parse_exp()
    }
    
    @discardableResult
    private func consume() -> Lexer.Token? {
        if idx >= tokens.count {
            return nil
        }
        let t = tokens[idx]
        idx += 1
        return t
    }
    
    private func peek() -> Lexer.Token? {
        if idx >= tokens.count {
            return nil
        }
        return tokens[idx]
    }
    
    private func parse_exp() -> Exp? {
        guard var left = parse_term() else {
            return nil
        }
        
        while let t = peek() {
            switch t {
            case .ADD:
                consume()
                
                guard let right = parse_term() else {
                    return nil
                }
                left = .Add(left, right)
            case .SUB:
                consume()
                
                guard let right = parse_term() else {
                    return nil
                }
                left = .Sub(left, right)
            default: return left
            }
        }
        
        return left
    }
    
    private func parse_term() -> Exp? {
        guard var left = parse_factor() else {
            return nil
        }
        
        while let t = peek() {
            switch t {
            case .MUL:
                consume()
                
                guard let right = parse_factor() else {
                    return nil
                }
                left = .Mul(left, right)
            case .DIV:
                consume()
                
                guard let right = parse_factor() else {
                    return nil
                }
                left = .Div(left, right)
            default: return left
            }
        }
        
        return left
    }
    
    private func parse_factor() -> Exp? {
        guard let t = consume() else {
            return nil
        }
        
        switch t {
        case .NUMBER(let x): return .Num(x)
        case .X: return .X
        case .Z: return .Z
        case .LP:
            let result = parse_exp()
            if consume() != .RP {
                return nil
            }
            return result
        default: return nil
        }
    }
}
