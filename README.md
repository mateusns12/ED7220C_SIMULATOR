# SIMULADOR ED7220C

### Este repositório contém os códigos desenvolvidos para o simulador do robô ED7220C no Coppelia Simulator, utilizado no Trabalho de Conclusão de Curso de Engenharia Mecatrônica.
---

## Linguagens de programação do robô
O robô ED7220C é um manipulador mecânico desenvolvido pela ED Corporation nos anos 2000. Pode ser programado através do controle serial Teach Pendant, ou pelo computador pelo programa Arm Robot Trainer. Portanto, há duas linguagens que podem ser utilizadas.
A linguagem RoboTalk, do Arm Robot Trainer, pode ser considerada um subset da linguagem BASIC. Alguns blocos de controle e laços são identicos, assim como a declaração de subrotinas e funções matemáticas. Entretanto há diferenças como declaração de variáveis, print na tela, variaveis locais, etc.
```basic
SETI B = 1
FOR A = B TO 5
    IF A = 5 THEN GOSUB 300 ELSE GOSUB 200
NEXT 
END
200 REM Corpo da Subrotina 200
TYPE "Subrotina 200"
OUTSIG 1
RETURN
300 REM Corpo da Subrotina 300
TYPE "Subrotina 300"
OUTSIG -1
RETURN
```
A linguagem utilizada no controle é um conjunto de instruções em formato ASCII, executado no computador ED-MK4 integrado ao robô, que se assemelha à programação em Assembbly, sendo um mnemonico para instrução, seguido dos argumentos separados por vírgula.

```asm
SL,2
OB,1,1
OB,1,0
GL,2
```
---

## Interpreter

O interpretador é responsável pela tokenização, parsing, e interpretação do código RoboTalk, que é executado em uma máquina virtual (função Interpreter:run()), onde a lista de instruções é convertida em funções do Coppelia e aciona o robô virtual.

---

## Emmiter

O emissor recebe a lista de instruções gerada pelo parser do interpretador e emite instruções do ED-MK4 em uma string ASCII via serial RS232. Desta forma, a aplicação pode controlar também o robô físico.

---

## Coppelia GUIs 

## Testes

