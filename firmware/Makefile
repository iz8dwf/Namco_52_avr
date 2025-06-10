SRCFILE = 52_M8515
MCU = m8515
TARGET = usbtiny
INCPATH = .

$(SRCFILE).hex: $(SRCFILE).asm
	avra -l $(SRCFILE).lst -I $(INCPATH) $(SRCFILE).asm

flash:
	avrdude -c $(TARGET) -p $(MCU) -U flash:w:$(SRCFILE).hex:i

fuse:
	avrdude -c $(TARGET) -p $(MCU) -U lfuse:w:0xE0:m
	avrdude -c $(TARGET) -p $(MCU) -U hfuse:w:0xD9:m

clean:
	rm -f $(SRCFILE).hex $(SRCFILE).obj $(SRCFILE).cof

