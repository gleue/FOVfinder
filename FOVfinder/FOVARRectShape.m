//
//  FOVARRectShape.m
//  FOVfinder
//
//  Created by Tim Gleue on 21.11.13.
//  Copyright (c) 2015 Tim Gleue ( http://gleue-interactive.com )
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "FOVARRectShape.h"

// GL data
//
typedef struct {
    
    float Position[3];
    
} Vertex;

static const Vertex Vertices[] = {
    
    { { +1, -1, 0 } },
    { { +1, +1, 0 } },
    { { -1, +1, 0 } },
    { { -1, -1, 0 } }
};

static const GLubyte Indices[] = { 0, 1, 2, 3, 0 };

@interface FOVARRectShape () {
    
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
};

@property (strong, nonatomic) GLKTextureInfo *textureInfo;

@end

@implementation FOVARRectShape

- (instancetype)initWithContext:(EAGLContext *)context size:(CGSize)size {
    
    self = [super initWithContext:context];
    
    if (self && self.context) {
        
        [EAGLContext setCurrentContext:self.context];

        self.effect = [[GLKBaseEffect alloc] init];
        self.effect.constantColor = GLKVector4Make(1.0, 1.0, 1.0, 1.0);

        float w2 = 0.5 * size.width;
        float h2 = 0.5 * size.height;
        
        static Vertex bgVertices[4];

        for (NSUInteger idx = 0; idx < 4; idx++) {
            
            bgVertices[idx].Position[0] = Vertices[idx].Position[0] * w2;
            bgVertices[idx].Position[1] = Vertices[idx].Position[1] * h2;
            bgVertices[idx].Position[2] = Vertices[idx].Position[2];
        }
        
        glGenBuffers(1, &_vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(bgVertices), bgVertices, GL_STATIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        
        glGenBuffers(1, &_indexBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }
    
    return self;
}

- (void)dealloc {
    
    if (self.context) {
        
        [EAGLContext setCurrentContext:self.context];
        
        glDeleteBuffers(1, &_indexBuffer); _indexBuffer = 0;
        glDeleteBuffers(1, &_vertexBuffer); _vertexBuffer = 0;
    }
}

#pragma mark - Methods

- (void)draw {
    
    if (self.context) {

        glLineWidth(3.0);

        [EAGLContext setCurrentContext:self.context];
        
        [self.effect prepareToDraw];

        glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
        glEnableVertexAttribArray(GLKVertexAttribPosition);
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, Position));
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        
        glDrawElements(GL_LINE_STRIP, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
}

@end
